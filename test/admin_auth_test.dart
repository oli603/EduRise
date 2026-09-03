import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/auth/user_role.dart';
import 'package:edurise/features/admin/data/admin_service.dart';

void main() {
  group('UserRole Unit Tests', () {
    test('UserRole.fromString correctly parses all roles', () {
      expect(UserRole.fromString('founder'), UserRole.founder);
      expect(UserRole.fromString('FOUNDER'), UserRole.founder);
      expect(UserRole.fromString('admin'), UserRole.admin);
      expect(UserRole.fromString('ADMIN'), UserRole.admin);
      expect(UserRole.fromString('student'), UserRole.student);
      expect(UserRole.fromString('STUDENT'), UserRole.student);
      expect(UserRole.fromString(null), UserRole.student);
      expect(UserRole.fromString('unknown_role'), UserRole.student);
      expect(UserRole.fromString(''), UserRole.student);
    });

    test('UserRole permission getters behave strictly according to hierarchy', () {
      // Founder has both founder and admin authority
      const founder = UserRole.founder;
      expect(founder.isFounder, isTrue);
      expect(founder.isAdmin, isTrue);
      expect(founder.isAuthorizedAdmin, isTrue);
      expect(founder.isStudent, isFalse);

      // Admin has admin authority but NOT founder authority
      const admin = UserRole.admin;
      expect(admin.isFounder, isFalse);
      expect(admin.isAdmin, isTrue);
      expect(admin.isAuthorizedAdmin, isTrue);
      expect(admin.isStudent, isFalse);

      // Student has neither admin nor founder authority
      const student = UserRole.student;
      expect(student.isFounder, isFalse);
      expect(student.isAdmin, isFalse);
      expect(student.isAuthorizedAdmin, isFalse);
      expect(student.isStudent, isTrue);
    });

    test('UserRole.value returns exact string representation', () {
      expect(UserRole.founder.value, 'founder');
      expect(UserRole.admin.value, 'admin');
      expect(UserRole.student.value, 'student');
    });
  });

  group('AdminService Email and Role Recognition Tests', () {
    test('Recognizes exact known Founder email', () {
      expect(AdminService.founderEmail, 'olanamengistu2@gmail.com');
      expect(AdminService.adminEmail, 'tamiratboja@gmail.com');
    });
  });
}
