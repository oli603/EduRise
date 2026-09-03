import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_service.dart';
import 'audit_service.dart';

class SystemSettings {
  final String cbeAccount;
  final String cbeAccountName;
  final String telebirrNumber;
  final double subscriptionPrice;
  final bool maintenanceMode;
  final String announcementBanner;

  const SystemSettings({
    required this.cbeAccount,
    required this.cbeAccountName,
    required this.telebirrNumber,
    required this.subscriptionPrice,
    required this.maintenanceMode,
    required this.announcementBanner,
  });

  factory SystemSettings.defaults() {
    return const SystemSettings(
      cbeAccount: '1000123456789',
      cbeAccountName: 'EduRise Academy',
      telebirrNumber: '0911000000',
      subscriptionPrice: 500.0,
      maintenanceMode: false,
      announcementBanner: '',
    );
  }

  factory SystemSettings.fromMap(Map<String, dynamic> data) {
    return SystemSettings(
      cbeAccount: data['cbeAccount'] as String? ?? '1000123456789',
      cbeAccountName: data['cbeAccountName'] as String? ?? 'EduRise Academy',
      telebirrNumber: data['telebirrNumber'] as String? ?? '0911000000',
      subscriptionPrice: (data['subscriptionPrice'] as num?)?.toDouble() ?? 500.0,
      maintenanceMode: data['maintenanceMode'] as bool? ?? false,
      announcementBanner: data['announcementBanner'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cbeAccount': cbeAccount,
      'cbeAccountName': cbeAccountName,
      'telebirrNumber': telebirrNumber,
      'subscriptionPrice': subscriptionPrice,
      'maintenanceMode': maintenanceMode,
      'announcementBanner': announcementBanner,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class AdminSettingsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      _firestore.collection('system_settings').doc('general');

  Future<SystemSettings> getSettings() async {
    final doc = await _settingsDoc.get();
    if (!doc.exists || doc.data() == null) {
      return SystemSettings.defaults();
    }
    return SystemSettings.fromMap(doc.data()!);
  }

  Future<void> updateSettings(SystemSettings settings) async {
    final isAuthorized = await AdminService.isCurrentAuthorizedAdmin();
    if (!isAuthorized) throw Exception('Unauthorized access.');

    await _settingsDoc.set(settings.toMap(), SetOptions(merge: true));

    await AuditService.logAction(
      action: 'system_settings_updated',
      targetType: 'system_settings',
      targetId: 'general',
      metadata: {
        'subscriptionPrice': settings.subscriptionPrice,
        'maintenanceMode': settings.maintenanceMode,
      },
    );
  }
}
