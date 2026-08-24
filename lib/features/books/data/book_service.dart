import 'package:cloud_firestore/cloud_firestore.dart';

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
