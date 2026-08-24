import 'package:cloud_firestore/cloud_firestore.dart';
import 'study_task_model.dart';

class StudyPlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tasksCollection =>
      _firestore.collection('study_tasks');

  /// Add a new study task.
  Future<String> addTask(StudyTask task) async {
    final document = _tasksCollection.doc();

    final taskWithMetadata = task.copyWith(
      id: document.id,
      createdAt: DateTime.now(),
    );

    await document.set({
      ...taskWithMetadata.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  /// Get all tasks belonging to a specific user.
  Future<List<StudyTask>> getUserTasks({required String userId}) async {
    final snapshot = await _tasksCollection
        .where('userId', isEqualTo: userId)
        .orderBy('scheduledDate')
        .get();

    return snapshot.docs
        .map((document) => StudyTask.fromMap(document.id, document.data()))
        .toList();
  }

  /// Get tasks scheduled for a specific day.
  Future<List<StudyTask>> getTasksForDate({
    required String userId,
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);

    final endOfDay = startOfDay.add(const Duration(days: 1));

    final snapshot = await _tasksCollection
        .where('userId', isEqualTo: userId)
        .where(
          'scheduledDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('scheduledDate', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('scheduledDate')
        .get();

    return snapshot.docs
        .map((document) => StudyTask.fromMap(document.id, document.data()))
        .toList();
  }

  /// Mark a task as completed or incomplete.
  Future<void> setTaskCompleted({
    required String taskId,
    required bool completed,
  }) async {
    await _tasksCollection.doc(taskId).update({'isCompleted': completed});
  }

  /// Delete a study task.
  Future<void> deleteTask(String taskId) async {
    await _tasksCollection.doc(taskId).delete();
  }

  /// Get one task by its ID.
  Future<StudyTask?> getTaskById(String taskId) async {
    final document = await _tasksCollection.doc(taskId).get();

    if (!document.exists) {
      return null;
    }

    return StudyTask.fromMap(document.id, document.data()!);
  }
}
