import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/edurise_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../data/models/payment_submission.dart';
import '../data/payment_service.dart';
import '../data/payment_settings_service.dart';

class SubmitPaymentScreen extends StatefulWidget {
  const SubmitPaymentScreen({super.key});

  @override
  State<SubmitPaymentScreen> createState() => _SubmitPaymentScreenState();
}

class _SubmitPaymentScreenState extends State<SubmitPaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  final PaymentSettingsService _settingsService = PaymentSettingsService();
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController(text: '1499');
  final _refController = TextEditingController();
  String _selectedMethod = 'Telebirr';
  File? _selectedReceiptFile;

  bool _isLoading = false;
  bool _isFetchingStatus = true;
  PaymentSubmission? _latestSubmission;
  PaymentSettings _systemSettings = PaymentSettings.defaults();

  final List<String> _paymentMethods = [
    'Telebirr',
    'Commercial Bank of Ethiopia (CBE)',
    'Bank of Abyssinia',
    'Awash Bank',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isFetchingStatus = true);
    await Future.wait([
      _loadLatestSubmission(),
      _loadSettings(),
    ]);
    if (mounted) {
      setState(() => _isFetchingStatus = false);
    }
  }

  Future<void> _loadLatestSubmission() async {
    try {
      final submission = await _paymentService.getMyLatestSubmission();
      if (mounted) {
        setState(() {
          _latestSubmission = submission;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await _settingsService.getPaymentSettings();
      if (mounted) {
        setState(() {
          _systemSettings = settings;
          if (_amountController.text.trim().isEmpty || _amountController.text.trim() == '500') {
            _amountController.text = settings.subscriptionPrice.toStringAsFixed(0);
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _pickReceiptImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedReceiptFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to select image. Please try again.')),
        );
      }
    }
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedReceiptFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach your payment receipt or screenshot.')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? _systemSettings.subscriptionPrice;

    setState(() => _isLoading = true);

    try {
      await _paymentService.submitPaymentProof(
        receiptFile: _selectedReceiptFile!,
        packageId: 'full_access',
        packageName: 'EduRise All-Access Pass',
        amount: amount,
        paymentMethod: _selectedMethod,
        transactionReference: _refController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment submitted successfully! Our team will verify it shortly.'),
          backgroundColor: AppColors.success,
        ),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment Verification',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _isFetchingStatus
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Status Banner if submission exists
                  if (_latestSubmission != null) ...[
                    _buildStatusCard(_latestSubmission!),
                    const SizedBox(height: 20),
                  ],

                  // If not approved, show instructions and form
                  if (_latestSubmission == null || _latestSubmission!.isRejected) ...[
                    _buildPaymentInstructionsCard(),
                    const SizedBox(height: 24),
                    _buildSubmissionForm(),
                  ] else if (_latestSubmission!.isApproved) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.success),
                      ),
                      color: AppColors.success.withValues(alpha: 0.08),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 52),
                            const SizedBox(height: 12),
                            const Text(
                              'All Features Unlocked!',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Your payment has been verified. You can now access all Practice questions, Book units, and exam materials.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => context.go('/home'),
                              child: const Text('Back to Home'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard(PaymentSubmission submission) {
    Color cardColor;
    Color iconColor;
    IconData icon;
    String title;
    String message;

    if (submission.isPending) {
      cardColor = AppColors.warning.withValues(alpha: 0.1);
      iconColor = AppColors.warning;
      icon = Icons.hourglass_top_rounded;
      title = 'Verification Pending';
      message =
          'Your payment receipt was submitted on ${submission.submittedAt?.toString().substring(0, 16) ?? 'recently'}. An administrator is reviewing your submission.';
    } else if (submission.isApproved) {
      cardColor = AppColors.success.withValues(alpha: 0.1);
      iconColor = AppColors.success;
      icon = Icons.verified_rounded;
      title = 'Payment Approved';
      message = 'Your payment of ${submission.amount.toStringAsFixed(0)} Birr has been confirmed. Full access is active.';
    } else {
      cardColor = AppColors.error.withValues(alpha: 0.1);
      iconColor = AppColors.error;
      icon = Icons.error_outline_rounded;
      title = 'Payment Rejected';
      message =
          'Reason: ${submission.rejectionReason ?? 'Receipt was unclear or invalid.'}\nPlease submit a new receipt below.';
    }

    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: iconColor.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: iconColor, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(fontSize: 13, color: context.eduColors.textPrimary, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentInstructionsCard() {
    final priceStr = _systemSettings.subscriptionPrice.toStringAsFixed(0);

    return Card(
      elevation: 0,
      color: context.eduColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: context.eduColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  'Payment Instructions',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: context.eduColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Transfer the subscription fee ($priceStr Birr) to one of the accounts below, then upload your screenshot or receipt:',
              style: TextStyle(fontSize: 13, color: context.eduColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            _buildAccountRow(
              'Telebirr',
              _systemSettings.telebirrNumber,
              'EduRise',
            ),
            Divider(height: 16, color: context.eduColors.border),
            _buildAccountRow(
              'CBE Account',
              _systemSettings.cbeAccount,
              _systemSettings.cbeAccountName,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountRow(String bank, String account, String name) {
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: account));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copied $account to clipboard'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bank,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: context.eduColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    style: TextStyle(color: context.eduColors.textSecondary, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      account,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmissionForm() {
    final priceStr = _systemSettings.subscriptionPrice.toStringAsFixed(0);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Submit Proof of Payment',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.eduColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Payment Method Dropdown
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _selectedMethod,
            decoration: const InputDecoration(
              labelText: 'Payment Method',
              prefixIcon: Icon(Icons.payment_rounded),
            ),
            items: _paymentMethods.map((method) {
              return DropdownMenuItem(
                value: method,
                child: Text(
                  method,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedMethod = val);
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Amount
          EduRiseTextField(
            label: 'Amount Paid (Birr)',
            hint: priceStr,
            controller: _amountController,
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.account_balance_wallet_rounded),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the amount paid.';
              }
              if (double.tryParse(value.trim()) == null) {
                return 'Please enter a valid number.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Transaction Reference
          EduRiseTextField(
            label: 'Transaction / Transfer Reference',
            hint: 'e.g. FT23490001 or Telebirr Tx ID',
            controller: _refController,
            prefixIcon: const Icon(Icons.tag_rounded),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter the transaction reference number.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          // Receipt File Picker
          Text(
            'Receipt Screenshot / Document',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: context.eduColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          InkWell(
            onTap: _pickReceiptImage,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: context.eduColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedReceiptFile != null ? AppColors.primary : context.eduColors.border,
                  width: _selectedReceiptFile != null ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedReceiptFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                    color: _selectedReceiptFile != null ? AppColors.primary : context.eduColors.textSecondary,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedReceiptFile != null
                        ? 'Selected: ${_selectedReceiptFile!.path.split(Platform.pathSeparator).last}'
                        : 'Tap to select receipt image or screenshot',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _selectedReceiptFile != null ? FontWeight.bold : FontWeight.normal,
                      color: _selectedReceiptFile != null ? AppColors.primary : context.eduColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Submit Button
          PrimaryButton(
            text: _isLoading ? 'Uploading Proof...' : 'Submit Receipt for Verification',
            onPressed: _isLoading ? null : _submitPayment,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
