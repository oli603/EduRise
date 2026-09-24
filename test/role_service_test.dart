import 'package:flutter_test/flutter_test.dart';
import 'package:edurise/core/auth/role_service.dart';
import 'package:edurise/core/auth/user_role.dart';
import 'package:edurise/core/auth/access_service.dart';
import 'package:edurise/features/admin/data/admin_service.dart';

void main() {
  setUp(() {
    RoleService.clearCache();
    AccessService.setTestRole(null);
  });

  tearDown(() {
    RoleService.clearCache();
    AccessService.setTestRole(null);
  });

  group('RoleService Bootstrap and Constants Tests', () {
    test('RoleService exposes authoritative bootstrap emails', () {
      expect(RoleService.founderEmail, 'olanamengistu2@gmail.com');
      expect(RoleService.adminEmail, 'tamiratboja@gmail.com');
    });

    test('AdminService delegates bootstrap emails to RoleService', () {
      expect(AdminService.founderEmail, RoleService.founderEmail);
      expect(AdminService.adminEmail, RoleService.adminEmail);
    });

    test('clearCache resets in-memory cache to safe defaults', () {
      RoleService.clearCache();
      expect(RoleService.isFounder, isFalse);
      expect(RoleService.isAdmin, isFalse);
      expect(RoleService.isAuthorizedAdmin, isFalse);
    });
  });

  group('RoleService Unauthenticated Behavior Tests', () {
    test('getCurrentRole returns UserRole.student when unauthenticated', () async {
      final role = await RoleService.getCurrentRole();
      expect(role, UserRole.student);
      expect(role.isStudent, isTrue);
      expect(role.isAdmin, isFalse);
      expect(role.isFounder, isFalse);
      expect(role.isAuthorizedAdmin, isFalse);
    });

    test('isCurrentAuthorizedAdmin returns false when unauthenticated', () async {
      final isAuthorized = await RoleService.isCurrentAuthorizedAdmin();
      expect(isAuthorized, isFalse);
    });

    test('isCurrentFounder returns false when unauthenticated', () async {
      final isFounder = await RoleService.isCurrentFounder();
      expect(isFounder, isFalse);
    });

    test('resolvePostAuthRoute returns /login when no user is signed in', () async {
      final destination = await RoleService.resolvePostAuthRoute();
      expect(destination, '/login');
    });

    test('AdminService.resolvePostAuthRoute delegates to RoleService cleanly', () async {
      final destination = await AdminService.resolvePostAuthRoute();
      expect(destination, '/login');
    });
  });

  group('AccessService Core Role Integration Tests', () {
    test('AccessService evaluates test roles correctly without admin feature dependency', () async {
      AccessService.setTestRole('paid');
      expect(await AccessService.hasPaidAccess(), isTrue);

      AccessService.setTestRole('admin');
      expect(await AccessService.hasPaidAccess(), isTrue);

      AccessService.setTestRole('student');
      expect(await AccessService.hasPaidAccess(), isFalse);
    });

    test('AccessService evaluates free allowed trial content strictly', () {
      // Allowed trial: Grade 12, 2017 EC, Unit 1
      expect(
        AccessService.isFreeAllowedPractice(
          grade: 'Grade 12',
          examYear: 2017,
          unitNumber: 1,
        ),
        isTrue,
      );

      // Denied trial: Grade 11
      expect(
        AccessService.isFreeAllowedPractice(
          grade: 'Grade 11',
          examYear: 2017,
          unitNumber: 1,
        ),
        isFalse,
      );

      // Denied trial: Unit 2
      expect(
        AccessService.isFreeAllowedPractice(
          grade: 'Grade 12',
          examYear: 2017,
          unitNumber: 2,
        ),
        isFalse,
      );

      // Denied trial: 2016 EC
      expect(
        AccessService.isFreeAllowedPractice(
          grade: 'Grade 12',
          examYear: 2016,
          unitNumber: 1,
        ),
        isFalse,
      );
    });
  });
}
