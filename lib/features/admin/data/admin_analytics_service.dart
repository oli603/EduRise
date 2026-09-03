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

    // Count students
    final studentsSnap = await _firestore.collection('students').limit(200).get();
    final totalStudents = studentsSnap.docs.length;
    int paidStudents = 0;
    final Map<String, int> gradeDist = {};

    for (final doc in studentsSnap.docs) {
      final data = doc.data();
      if (data['isPaid'] == true || data['accessStatus'] == 'active') {
        paidStudents++;
      }
      final grade = data['grade'] as String? ?? 'Not Specified';
      gradeDist[grade] = (gradeDist[grade] ?? 0) + 1;
    }

    // Payments breakdown
    final paymentsSnap = await _firestore.collection('payment_submissions').limit(200).get();
    int pending = 0;
    int approved = 0;
    int rejected = 0;
    double revenue = 0.0;
    final Map<String, int> methodBreakdown = {};

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

    // Question count
    final questionsCountSnap = await _firestore.collection('questions').count().get();
    final totalQuestions = questionsCountSnap.count ?? 0;

    // Packages count
    final packagesCountSnap = await _firestore.collection('question_packages').count().get();
    final totalPackages = packagesCountSnap.count ?? 0;

    // Book units count
    final booksCountSnap = await _firestore.collection('book_units').count().get();
    final totalBooks = booksCountSnap.count ?? 0;

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
