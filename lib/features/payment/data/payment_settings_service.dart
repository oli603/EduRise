import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentSettings {
  final String cbeAccount;
  final String cbeAccountName;
  final String telebirrNumber;
  final double subscriptionPrice;

  const PaymentSettings({
    required this.cbeAccount,
    required this.cbeAccountName,
    required this.telebirrNumber,
    required this.subscriptionPrice,
  });

  factory PaymentSettings.defaults() {
    return const PaymentSettings(
      cbeAccount: '1000123456789',
      cbeAccountName: 'EduRise Academy',
      telebirrNumber: '0911000000',
      subscriptionPrice: 1499.0,
    );
  }

  factory PaymentSettings.fromMap(Map<String, dynamic> data) {
    return PaymentSettings(
      cbeAccount: data['cbeAccount'] as String? ?? '1000123456789',
      cbeAccountName: data['cbeAccountName'] as String? ?? 'EduRise Academy',
      telebirrNumber: data['telebirrNumber'] as String? ?? '0911000000',
      subscriptionPrice: (data['subscriptionPrice'] as num?)?.toDouble() ?? 1499.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'cbeAccount': cbeAccount,
      'cbeAccountName': cbeAccountName,
      'telebirrNumber': telebirrNumber,
      'subscriptionPrice': subscriptionPrice,
    };
  }
}

class PaymentSettingsService {
  final FirebaseFirestore? _customFirestore;

  PaymentSettingsService({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      _firestore.collection('system_settings').doc('general');

  Stream<PaymentSettings> getPaymentSettingsStream() {
    return _settingsDoc.snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return PaymentSettings.defaults();
      }
      return PaymentSettings.fromMap(doc.data()!);
    }).handleError((_) => PaymentSettings.defaults());
  }

  Future<PaymentSettings> getPaymentSettings() async {
    try {
      final doc = await _settingsDoc.get();
      if (!doc.exists || doc.data() == null) {
        return PaymentSettings.defaults();
      }
      return PaymentSettings.fromMap(doc.data()!);
    } catch (_) {
      return PaymentSettings.defaults();
    }
  }
}
