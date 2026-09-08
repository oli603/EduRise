import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_service.dart';

class AdminAnalyticsData {
  final int totalStudents;
  final int paidStudents;
  final double totalRevenue;
  final int pendingPayments;
  final int approvedPayments;
  final int rejectedPayments;
  final int totalQuestions;
  final int totalPackages;
  final int totalBookUnits;
  final Map<String, int> paymentMethodBreakdown;
  final Map<String, int> gradeDistribution;

  const AdminAnalyticsData({
    required this.totalStudents,
    required this.paidStudents,
    required this.totalRevenue,
    required this.pendingPayments,
    required this.approvedPayments,
    required this.rejectedPayments,
    required this.totalQuestions,
    required this.totalPackages,
    required this.totalBookUnits,
    required this.paymentMethodBreakdown,
    required this.gradeDistribution,
  });
}

class AdminAnalyticsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<AdminAnalyticsData> getAnalyticsData() async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) throw Exception('Unauthorized access.');

    int totalStudents = 0;
    int paidStudents = 0;
    final Map<String, int> gradeDist = {};

    // 1. Efficient statistical aggregates for student metrics (least-privilege, low bandwidth)
    try {
      final totalCountSnap = await _firestore.collection('students').count().get();
      totalStudents = totalCountSnap.count ?? 0;

      final paidCountSnap = await _firestore
          .collection('students')
          .where('isPaid', isEqualTo: true)
          .count()
          .get();
      paidStudents = paidCountSnap.count ?? 0;

      // Sample grade distribution without loading the entire collection
      final sampleSnap = await _firestore.collection('students').limit(100).get();
      for (final doc in sampleSnap.docs) {
        final grade = doc.data()['grade'] as String? ?? 'Not Specified';
        gradeDist[grade] = (gradeDist[grade] ?? 0) + 1;
      }
    } catch (_) {
      // Bounded fallback if count() aggregation is unsupported
      final studentsSnap = await _firestore.collection('students').limit(100).get();
      totalStudents = studentsSnap.docs.length;
      for (final doc in studentsSnap.docs) {
        final data = doc.data();
        if (data['isPaid'] == true || data['accessStatus'] == 'active') {
          paidStudents++;
        }
        final grade = data['grade'] as String? ?? 'Not Specified';
        gradeDist[grade] = (gradeDist[grade] ?? 0) + 1;
      }
    }

    // 2. Payments breakdown
    int pending = 0;
    int approved = 0;
    int rejected = 0;
    double revenue = 0.0;
    final Map<String, int> methodBreakdown = {};

    try {
      final paymentsSnap = await _firestore
          .collection('payment_submissions')
          .orderBy('submittedAt', descending: true)
          .limit(100)
          .get();

      for (final doc in paymentsSnap.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? 'pending';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final method = data['paymentMethod'] as String? ?? 'Other';

        methodBreakdown[method] = (methodBreakdown[method] ?? 0) + 1;

        if (status == 'approved') {
          approved++;
          revenue += amount;
        } else if (status == 'rejected') {
          rejected++;
        } else {
          pending++;
        }
      }
    } catch (_) {}

    // 3. Question count
    int totalQuestions = 0;
    try {
      final questionsCountSnap = await _firestore.collection('questions').count().get();
      totalQuestions = questionsCountSnap.count ?? 0;
    } catch (_) {}

    // 4. Packages count
    int totalPackages = 0;
    try {
      final packagesCountSnap = await _firestore.collection('question_packages').count().get();
      totalPackages = packagesCountSnap.count ?? 0;
    } catch (_) {}

    // 5. Book units count
    int totalBooks = 0;
    try {
      final booksCountSnap = await _firestore.collection('book_units').count().get();
      totalBooks = booksCountSnap.count ?? 0;
    } catch (_) {}

    return AdminAnalyticsData(
      totalStudents: totalStudents,
      paidStudents: paidStudents,
      totalRevenue: revenue,
      pendingPayments: pending,
      approvedPayments: approved,
      rejectedPayments: rejected,
      totalQuestions: totalQuestions,
      totalPackages: totalPackages,
      totalBookUnits: totalBooks,
      paymentMethodBreakdown: methodBreakdown,
      gradeDistribution: gradeDist,
    );
  }
}
