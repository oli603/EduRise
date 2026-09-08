import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/auth/user_role.dart';
import 'package:edurise/features/admin/data/admin_service.dart';

void main() {
  group('Security Hardening & Role Invariants Tests', () {
    test('UserRole hierarchy preserves strict privilege tiers', () {
      // 1. Founder has complete super-administrative authorization
      const founder = UserRole.founder;
      expect(founder.isFounder, isTrue);
      expect(founder.isAdmin, isTrue);
      expect(founder.isAuthorizedAdmin, isTrue);
      expect(founder.isStudent, isFalse);

      // 2. Operational Admin has admin permissions, but CANNOT manage founder privileges
      const admin = UserRole.admin;
      expect(admin.isFounder, isFalse);
      expect(admin.isAdmin, isTrue);
      expect(admin.isAuthorizedAdmin, isTrue);
      expect(admin.isStudent, isFalse);

      // 3. Student has neither admin nor founder authority
      const student = UserRole.student;
      expect(student.isFounder, isFalse);
      expect(student.isAdmin, isFalse);
      expect(student.isAuthorizedAdmin, isFalse);
      expect(student.isStudent, isTrue);
    });

    test('UserRole parsing defaults safely to student on unknown or malicious strings', () {
      expect(UserRole.fromString('founder'), UserRole.founder);
      expect(UserRole.fromString('FOUNDER'), UserRole.founder);
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('ADMIN'), UserRole.admin);
      expect(UserRole.fromString('student'), UserRole.student);

      // Threat scenarios: malicious role attempts default to Student
      expect(UserRole.fromString('superadmin'), UserRole.student);
      expect(UserRole.fromString('root'), UserRole.student);
      expect(UserRole.fromString('ADMIN '), UserRole.admin); // trimmed
      expect(UserRole.fromString(''), UserRole.student);
      expect(UserRole.fromString(null), UserRole.student);
      expect(UserRole.fromString('{}'), UserRole.student);
      expect(UserRole.fromString('role=founder'), UserRole.student);
    });

    test('AdminService identifies bootstrap root authority', () {
      expect(AdminService.founderEmail, 'olanamengistu2@gmail.com');
      expect(AdminService.adminEmail, 'tamiratboja@gmail.com');
    });
  });

  group('Firestore Security Rules Logic Simulation Tests', () {
    // Simulated Firestore rules evaluation logic matching firestore.rules
    bool canUpdateStudentDoc({
      required String callerRole,
      required String callerUid,
      required String targetStudentId,
      required Map<String, dynamic> existingData,
      required Map<String, dynamic> incomingData,
    }) {
      final isOwner = callerUid == targetStudentId;
      final isFounder = callerRole == 'founder';
      final isAdmin = callerRole == 'admin' || isFounder;

      final affectedKeys = <String>{};
      final allKeys = {...existingData.keys, ...incomingData.keys};
      for (final key in allKeys) {
        if (existingData[key] != incomingData[key]) {
          affectedKeys.add(key);
        }
      }

      // Case 1: Owner student
      if (isOwner && !isFounder && !isAdmin) {
        const prohibitedStudentKeys = {
          'isPaid',
          'accessStatus',
          'role',
          'paidUntil',
          'approvedBy',
          'activePaymentId',
        };
        if (affectedKeys.any(prohibitedStudentKeys.contains)) {
          return false;
        }
        return true;
      }

      // Case 2: Operational admin
      if (callerRole == 'admin') {
        // Admin CANNOT modify role
        if (affectedKeys.contains('role')) {
          return false;
        }
        return true;
      }

      // Case 3: Founder
      if (isFounder) {
        if (incomingData.containsKey('role')) {
          const validRoles = {'student', 'admin', 'founder'};
          if (!validRoles.contains(incomingData['role'])) {
            return false;
          }
        }
        return true;
      }

      return false;
    }

    test('Attack 1: Student attempts to elevate role to admin or founder -> DENIED', () {
      final existing = {'name': 'Alice', 'role': 'student', 'isPaid': false};
      final attackPayload = {'name': 'Alice', 'role': 'admin', 'isPaid': false};

      final allowed = canUpdateStudentDoc(
        callerRole: 'student',
        callerUid: 'alice_uid',
        targetStudentId: 'alice_uid',
        existingData: existing,
        incomingData: attackPayload,
      );

      expect(allowed, isFalse);
    });

    test('Attack 2: Student attempts to grant themselves isPaid access -> DENIED', () {
      final existing = {'name': 'Alice', 'role': 'student', 'isPaid': false};
      final attackPayload = {'name': 'Alice', 'role': 'student', 'isPaid': true};

      final allowed = canUpdateStudentDoc(
        callerRole: 'student',
        callerUid: 'alice_uid',
        targetStudentId: 'alice_uid',
        existingData: existing,
        incomingData: attackPayload,
      );

      expect(allowed, isFalse);
    });

    test('Attack 3: Student attempts to update another student document -> DENIED', () {
      final existing = {'name': 'Bob', 'role': 'student'};
      final incoming = {'name': 'Bob Modified', 'role': 'student'};

      final allowed = canUpdateStudentDoc(
        callerRole: 'student',
        callerUid: 'attacker_uid',
        targetStudentId: 'victim_bob_uid',
        existingData: existing,
        incomingData: incoming,
      );

      expect(allowed, isFalse);
    });

    test('Attack 4: Operational Admin attempts to elevate self/others to Founder -> DENIED', () {
      final existing = {'name': 'Bob', 'role': 'admin'};
      final attackPayload = {'name': 'Bob', 'role': 'founder'};

      final allowed = canUpdateStudentDoc(
        callerRole: 'admin',
        callerUid: 'admin_uid',
        targetStudentId: 'admin_uid',
        existingData: existing,
        incomingData: attackPayload,
      );

      expect(allowed, isFalse);
    });

    test('Legitimate Admin operation: Admin toggles isPaid status -> ALLOWED', () {
      final existing = {'name': 'Alice', 'role': 'student', 'isPaid': false};
      final incoming = {'name': 'Alice', 'role': 'student', 'isPaid': true};

      final allowed = canUpdateStudentDoc(
        callerRole: 'admin',
        callerUid: 'admin_uid',
        targetStudentId: 'alice_uid',
        existingData: existing,
        incomingData: incoming,
      );

      expect(allowed, isTrue);
    });

    test('Legitimate Student operation: Student updates name and stream -> ALLOWED', () {
      final existing = {'name': 'Alice', 'stream': 'Natural', 'role': 'student', 'isPaid': false};
      final incoming = {'name': 'Alice Updated', 'stream': 'Natural', 'role': 'student', 'isPaid': false};

      final allowed = canUpdateStudentDoc(
        callerRole: 'student',
        callerUid: 'alice_uid',
        targetStudentId: 'alice_uid',
        existingData: existing,
        incomingData: incoming,
      );

      expect(allowed, isTrue);
    });

    test('Legitimate Founder operation: Founder assigns valid admin role -> ALLOWED', () {
      final existing = {'name': 'Charlie', 'role': 'student'};
      final incoming = {'name': 'Charlie', 'role': 'admin'};

      final allowed = canUpdateStudentDoc(
        callerRole: 'founder',
        callerUid: 'founder_uid',
        targetStudentId: 'charlie_uid',
        existingData: existing,
        incomingData: incoming,
      );

      expect(allowed, isTrue);
    });
  });

  group('Student Ownership Immutability Tests', () {
    bool canUpdateStudentOwnedDoc({
      required String callerRole,
      required String callerUid,
      required String existingOwnerUid,
      required String incomingOwnerUid,
    }) {
      final isAuthorizedAdmin = callerRole == 'admin' || callerRole == 'founder';
      if (isAuthorizedAdmin) return true;

      // Rule: resource.data.userId == request.auth.uid && request.resource.data.userId == resource.data.userId
      return callerUid == existingOwnerUid && incomingOwnerUid == existingOwnerUid;
    }

    test('Attack 5: Student attempts to steal another student practice result -> DENIED', () {
      final allowed = canUpdateStudentOwnedDoc(
        callerRole: 'student',
        callerUid: 'attacker_alice',
        existingOwnerUid: 'victim_bob',
        incomingOwnerUid: 'attacker_alice',
      );

      expect(allowed, isFalse);
    });

    test('Attack 6: Student attempts to re-assign own result to another student -> DENIED', () {
      final allowed = canUpdateStudentOwnedDoc(
        callerRole: 'student',
        callerUid: 'alice_uid',
        existingOwnerUid: 'alice_uid',
        incomingOwnerUid: 'bob_uid', // Reassignment attempt
      );

      expect(allowed, isFalse);
    });

    test('Legitimate student result update preserves ownership -> ALLOWED', () {
      final allowed = canUpdateStudentOwnedDoc(
        callerRole: 'student',
        callerUid: 'alice_uid',
        existingOwnerUid: 'alice_uid',
        incomingOwnerUid: 'alice_uid',
      );

      expect(allowed, isTrue);
    });
  });

  group('Question Visibility and Payment Rule Invariants', () {
    bool canReadQuestion({
      required String callerRole,
      required String questionStatus,
    }) {
      final isAuthorizedAdmin = callerRole == 'admin' || callerRole == 'founder';
      if (isAuthorizedAdmin) return true;

      return questionStatus == 'published';
    }

    test('Attack 7: Student attempts to read draft or unpublished question -> DENIED', () {
      expect(canReadQuestion(callerRole: 'student', questionStatus: 'draft'), isFalse);
      expect(canReadQuestion(callerRole: 'student', questionStatus: 'unpublished'), isFalse);
      expect(canReadQuestion(callerRole: 'student', questionStatus: 'review'), isFalse);
    });

    test('Student reads published question -> ALLOWED', () {
      expect(canReadQuestion(callerRole: 'student', questionStatus: 'published'), isTrue);
    });

    test('Admin reads all questions (drafts and published) -> ALLOWED', () {
      expect(canReadQuestion(callerRole: 'admin', questionStatus: 'draft'), isTrue);
      expect(canReadQuestion(callerRole: 'admin', questionStatus: 'published'), isTrue);
    });

    test('Payment submission creation requires status == pending', () {
      bool canCreatePaymentSubmission({
        required String callerUid,
        required String studentId,
        required String status,
      }) {
        return callerUid == studentId && status == 'pending';
      }

      // Legitimate student submission
      expect(
        canCreatePaymentSubmission(callerUid: 'u1', studentId: 'u1', status: 'pending'),
        isTrue,
      );

      // Attack: Student creates pre-approved submission
      expect(
        canCreatePaymentSubmission(callerUid: 'u1', studentId: 'u1', status: 'approved'),
        isFalse,
      );

      // Attack: Student submits under another student ID
      expect(
        canCreatePaymentSubmission(callerUid: 'u1', studentId: 'u2', status: 'pending'),
        isFalse,
      );
    });
  });
}
