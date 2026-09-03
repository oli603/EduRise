enum UserRole {
  student,
  admin,
  founder;

  static UserRole fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'founder':
        return UserRole.founder;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }

  String get value {
    switch (this) {
      case UserRole.founder:
        return 'founder';
      case UserRole.admin:
        return 'admin';
      case UserRole.student:
        return 'student';
    }
  }

  bool get isFounder => this == UserRole.founder;
  bool get isAdmin => this == UserRole.admin || this == UserRole.founder;
  bool get isAuthorizedAdmin => this == UserRole.admin || this == UserRole.founder;
  bool get isStudent => this == UserRole.student;
}
