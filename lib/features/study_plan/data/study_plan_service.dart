import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'local/study_task_store.dart';
import '../../notifications/data/notification_service.dart';
import 'study_task_model.dart';

class StudyPlanService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final StudyTaskStore _storage = StudyTaskStore();

  CollectionReference<Map<String, dynamic>> get _tasksCollection =>
      _firestore.collection('study_tasks');

  /// Add a new study task and schedule its local notification reminder.
  Future<String> addTask(StudyTask task) async {
    final docId = task.id.isNotEmpty ? task.id : _tasksCollection.doc().id;

    final taskWithMetadata = task.copyWith(
      id: docId,
      createdAt: task.createdAt ?? DateTime.now(),
    );

    // Save locally
    await _storage.saveStudyTaskLocally(taskWithMetadata);

    // Schedule local notification on device
    await _notificationService.scheduleStudyTaskReminder(
      taskId: docId,
      subject: task.subject,
      title: task.title,
      scheduledDate: task.scheduledDate,
      isCompleted: task.isCompleted,
    );

    // Try remote write
    try {
      await _tasksCollection.doc(docId).set({
        ...taskWithMetadata.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('StudyPlanService addTask offline error: $e');
      await _storage.queuePendingStudyTaskOp({
        'opId': '${DateTime.now().millisecondsSinceEpoch}_create_$docId',
        'type': 'create',
        'taskId': docId,
        'data': taskWithMetadata.toMap(),
      });
    }

    return docId;
  }

  /// Update an existing study task and update its scheduled reminder.
  Future<void> updateTask(StudyTask task) async {
    // Save locally
    await _storage.saveStudyTaskLocally(task);

    // Cancel previous and reschedule if not completed
    await _notificationService.cancelStudyTaskReminder(task.id);
    if (!task.isCompleted) {
      await _notificationService.scheduleStudyTaskReminder(
        taskId: task.id,
        subject: task.subject,
        title: task.title,
        scheduledDate: task.scheduledDate,
        isCompleted: task.isCompleted,
      );
    }

    // Try remote update
    try {
      await _tasksCollection.doc(task.id).update(task.toMap()).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('StudyPlanService updateTask offline error: $e');
      await _storage.queuePendingStudyTaskOp({
        'opId': '${DateTime.now().millisecondsSinceEpoch}_update_${task.id}',
        'type': 'update',
        'taskId': task.id,
        'data': task.toMap(),
      });
    }
  }

  /// Get all tasks belonging to a specific user.
  Future<List<StudyTask>> getUserTasks({required String userId}) async {
    try {
      final snapshot = await _tasksCollection
          .where('userId', isEqualTo: userId)
          .orderBy('scheduledDate')
          .get()
          .timeout(const Duration(seconds: 4));

      final remoteTasks = snapshot.docs
          .map((doc) => StudyTask.fromMap(doc.id, doc.data()))
          .toList();

      await _storage.syncStudyTasksFromRemote(remoteTasks);
    } catch (e) {
      debugPrint('StudyPlanService getUserTasks offline error: $e');
    }

    return _storage.getLocalStudyTasks(userId: userId);
  }

  /// Get tasks scheduled for a specific day.
  Future<List<StudyTask>> getTasksForDate({
    required String userId,
    required DateTime date,
  }) async {
    final allTasks = await getUserTasks(userId: userId);

    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return allTasks.where((task) {
      final sDate = task.scheduledDate;
      return !sDate.isBefore(startOfDay) && sDate.isBefore(endOfDay);
    }).toList();
  }

  /// Mark a task as completed or incomplete and adjust scheduled reminder accordingly.
  Future<void> setTaskCompleted({
    required String taskId,
    required bool completed,
  }) async {
    final task = await getTaskById(taskId);
    if (task != null) {
      final updated = task.copyWith(isCompleted: completed);
      await _storage.saveStudyTaskLocally(updated);
    }

    if (completed) {
      await _notificationService.cancelStudyTaskReminder(taskId);
    } else {
      if (task != null && task.scheduledDate.isAfter(DateTime.now())) {
        await _notificationService.scheduleStudyTaskReminder(
          taskId: task.id,
          subject: task.subject,
          title: task.title,
          scheduledDate: task.scheduledDate,
          isCompleted: false,
        );
      }
    }

    try {
      await _tasksCollection.doc(taskId).update({'isCompleted': completed}).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('StudyPlanService setTaskCompleted offline error: $e');
      await _storage.queuePendingStudyTaskOp({
        'opId': '${DateTime.now().millisecondsSinceEpoch}_complete_$taskId',
        'type': 'complete',
        'taskId': taskId,
        'data': {'isCompleted': completed},
      });
    }
  }

  /// Delete a study task and cancel its scheduled local notification.
  Future<void> deleteTask(String taskId) async {
    await _notificationService.cancelStudyTaskReminder(taskId);
    await _storage.deleteStudyTaskLocally(taskId);

    try {
      await _tasksCollection.doc(taskId).delete().timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('StudyPlanService deleteTask offline error: $e');
      await _storage.queuePendingStudyTaskOp({
        'opId': '${DateTime.now().millisecondsSinceEpoch}_delete_$taskId',
        'type': 'delete',
        'taskId': taskId,
      });
    }
  }

  /// Get one task by its ID.
  Future<StudyTask?> getTaskById(String taskId) async {
    await _storage.init();
    final allUserTasks = await _storage.getLocalStudyTasks(userId: '');
    for (final t in allUserTasks) {
      if (t.id == taskId) return t;
    }

    try {
      final document = await _tasksCollection.doc(taskId).get().timeout(const Duration(seconds: 3));
      if (document.exists) {
        final task = StudyTask.fromMap(document.id, document.data()!);
        await _storage.saveStudyTaskLocally(task);
        return task;
      }
    } catch (_) {}

    return null;
  }
}
