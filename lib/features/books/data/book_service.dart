import 'package:cloud_firestore/cloud_firestore.dart';

import '../../admin/data/admin_service.dart';
import '../../admin/data/audit_service.dart';
import 'book_model.dart';

class BookService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _unitsCollection =>
      _firestore.collection('book_units');

  Future<void> addUnit(BookUnit unit) async {
    final document = _unitsCollection.doc();

    await document.set({
      ...unit.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await AuditService.logAction(
      action: 'book_unit_added',
      targetType: 'book_unit',
      targetId: document.id,
      metadata: {
        'grade': unit.grade,
        'subject': unit.subject,
        'unitNumber': unit.unitNumber,
        'unitName': unit.unitName,
      },
    );
  }

  Future<List<BookUnit>> getUnits({
    required String grade,
    required String subject,
  }) async {
    final snapshot = await _unitsCollection
        .where('grade', isEqualTo: grade)
        .where('subject', isEqualTo: subject)
        .orderBy('unitNumber')
        .get();

    return snapshot.docs
        .map((document) => BookUnit.fromMap(document.id, document.data()))
        .toList();
  }

  Future<List<BookUnit>> getAllUnits({
    String? grade,
    String? subject,
    int limit = 100,
  }) async {
    Query<Map<String, dynamic>> query = _unitsCollection.orderBy('createdAt', descending: true);

    if (grade != null && grade.isNotEmpty && grade != 'all') {
      query = query.where('grade', isEqualTo: grade);
    }

    if (subject != null && subject.isNotEmpty && subject != 'all') {
      query = query.where('subject', isEqualTo: subject);
    }

    final snapshot = await query.limit(limit).get();
    return snapshot.docs
        .map((document) => BookUnit.fromMap(document.id, document.data()))
        .toList();
  }

  Future<int> getTotalUnitsCount() async {
    final snapshot = await _unitsCollection.count().get();
    return snapshot.count ?? 0;
  }

  Future<void> deleteUnit(String unitId) async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) throw Exception('Unauthorized access.');

    final doc = await _unitsCollection.doc(unitId).get();
    final data = doc.data() ?? {};

    await _unitsCollection.doc(unitId).delete();

    await AuditService.logAction(
      action: 'book_unit_deleted',
      targetType: 'book_unit',
      targetId: unitId,
      metadata: {
        'grade': data['grade'],
        'subject': data['subject'],
        'unitNumber': data['unitNumber'],
      },
    );
  }

  Future<BookUnit?> getUnitById(String unitId) async {
    final document = await _unitsCollection.doc(unitId).get();

    if (!document.exists) {
      return null;
    }

    return BookUnit.fromMap(document.id, document.data()!);
  }

  Future<bool> unitExists({
    required String grade,
    required String subject,
    required int unitNumber,
  }) async {
    final snapshot = await _unitsCollection
        .where('grade', isEqualTo: grade)
        .where('subject', isEqualTo: subject)
        .where('unitNumber', isEqualTo: unitNumber)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }
}
