import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/edurise_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../admin/data/models/payment_model.dart';
import '../../admin/data/payment_service.dart';

class SubmitPaymentScreen extends StatefulWidget {
  const SubmitPaymentScreen({super.key});

  @override
  State<SubmitPaymentScreen> createState() => _SubmitPaymentScreenState();
}

class _SubmitPaymentScreenState extends State<SubmitPaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  final _formKey = GlobalKey<FormState>();

  final _amountController = TextEditingController(text: '500');
  final _refController = TextEditingController();
  String _selectedMethod = 'Telebirr';
  File? _selectedReceiptFile;

  bool _isLoading = false;
  bool _isFetchingStatus = true;
  PaymentSubmission? _latestSubmission;

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
    _loadLatestSubmission();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _refController.dispose();
    super.dispose();
  }

  Future<void> _loadLatestSubmission() async {
    setState(() => _isFetchingStatus = true);
    try {
      final submission = await _paymentService.getMyLatestSubmission();
      if (mounted) {
        setState(() {
          _latestSubmission = submission;
          _isFetchingStatus = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isFetchingStatus = false);
      }
    }
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

    final amount = double.tryParse(_amountController.text.trim()) ?? 500.0;

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

      await _loadLatestSubmission();
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
              onRefresh: _loadLatestSubmission,
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
                      color: AppColors.success.withOpacity(0.08),
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
      cardColor = AppColors.warning.withOpacity(0.1);
      iconColor = AppColors.warning;
      icon = Icons.hourglass_top_rounded;
      title = 'Verification Pending';
      message =
          'Your payment receipt was submitted on ${submission.submittedAt?.toString().substring(0, 16) ?? 'recently'}. An administrator is reviewing your submission.';
    } else if (submission.isApproved) {
      cardColor = AppColors.success.withOpacity(0.1);
      iconColor = AppColors.success;
      icon = Icons.verified_rounded;
      title = 'Payment Approved';
      message = 'Your payment of ${submission.amount.toStringAsFixed(0)} ETB has been confirmed. Full access is active.';
    } else {
      cardColor = AppColors.error.withOpacity(0.1);
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
        side: BorderSide(color: iconColor.withOpacity(0.4)),
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
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.3),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
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
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Payment Instructions',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'Transfer the subscription fee (500 ETB) to one of the accounts below, then upload your screenshot or receipt:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 14),
            _buildAccountRow('Telebirr', '0911000000', 'EduRise'),
            const Divider(height: 16),
            _buildAccountRow('CBE Account', '1000123456789', 'EduRise Academy'),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountRow(String bank, String account, String name) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(bank, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(name, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
        SelectableText(
          account,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmissionForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Submit Proof of Payment',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Payment Method Dropdown
          DropdownButtonFormField<String>(
            initialValue: _selectedMethod,
            decoration: const InputDecoration(
              labelText: 'Payment Method',
              prefixIcon: Icon(Icons.payment_rounded),
            ),
            items: _paymentMethods.map((method) {
              return DropdownMenuItem(value: method, child: Text(method));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedMethod = val);
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // Amount
          EduRiseTextField(
            label: 'Amount Paid (ETB)',
            hint: '500',
            controller: _amountController,
            keyboardType: TextInputType.number,
            prefixIcon: const Icon(Icons.attach_money_rounded),
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
          const Text(
            'Receipt Screenshot / Document',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 8),

          InkWell(
            onTap: _pickReceiptImage,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedReceiptFile != null ? AppColors.primary : AppColors.border,
                  width: _selectedReceiptFile != null ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedReceiptFile != null ? Icons.check_circle_rounded : Icons.cloud_upload_outlined,
                    color: _selectedReceiptFile != null ? AppColors.primary : AppColors.textSecondary,
                    size: 40,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _selectedReceiptFile != null
                        ? 'Selected: ${_selectedReceiptFile!.path.split(Platform.pathSeparator).last}'
                        : 'Tap to select receipt image or screenshot',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: _selectedReceiptFile != null ? FontWeight.bold : FontWeight.normal,
                      color: _selectedReceiptFile != null ? AppColors.primary : AppColors.textSecondary,
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
