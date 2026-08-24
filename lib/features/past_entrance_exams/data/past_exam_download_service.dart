import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';

class PastExamDownloadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Downloads one complete exam from Firestore
  /// and saves it locally on the student's device.
  Future<void> downloadExam({required String examId}) async {
    // 1. Get exam from Firestore
    final document = await _firestore
        .collection('past_exams')
        .doc(examId)
        .get();

    if (!document.exists) {
      throw Exception('Exam not found.');
    }

    final data = document.data();

    if (data == null) {
      throw Exception('Exam data is empty.');
    }

    // 2. Get the application documents directory
    final directory = await getApplicationDocumentsDirectory();

    // 3. Create our EduRise offline exam folder
    final examDirectory = Directory('${directory.path}/edurise_past_exams');

    if (!await examDirectory.exists()) {
      await examDirectory.create(recursive: true);
    }

    // 4. Create a local file for this exam
    final file = File('${examDirectory.path}/$examId.json');

    // 5. Convert Firestore data to JSON
    final jsonData = jsonEncode(data);

    // 6. Save the exam locally
    await file.writeAsString(jsonData);
  }

  /// Checks whether an exam has already been downloaded.
  Future<bool> isExamDownloaded({required String examId}) async {
    final directory = await getApplicationDocumentsDirectory();

    final file = File('${directory.path}/edurise_past_exams/$examId.json');

    return file.exists();
  }

  /// Loads an already downloaded exam.
  ///
  /// This method does NOT use Firestore.
  /// It reads directly from the device.
  Future<Map<String, dynamic>> getDownloadedExam({
    required String examId,
  }) async {
    final directory = await getApplicationDocumentsDirectory();

    final file = File('${directory.path}/edurise_past_exams/$examId.json');

    if (!await file.exists()) {
      throw Exception('This exam has not been downloaded.');
    }

    final jsonString = await file.readAsString();

    final decoded = jsonDecode(jsonString);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid downloaded exam data.');
    }

    return decoded;
  }

  /// Deletes a downloaded exam from the device.
  Future<void> deleteDownloadedExam({required String examId}) async {
    final directory = await getApplicationDocumentsDirectory();

    final file = File('${directory.path}/edurise_past_exams/$examId.json');

    if (await file.exists()) {
      await file.delete();
    }
  }
}
