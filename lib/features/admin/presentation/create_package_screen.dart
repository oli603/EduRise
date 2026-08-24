import 'package:flutter/material.dart';

import '../data/question_package_service.dart';

class CreatePackageScreen extends StatefulWidget {
  const CreatePackageScreen({super.key});

  @override
  State<CreatePackageScreen> createState() => _CreatePackageScreenState();
}

class _CreatePackageScreenState extends State<CreatePackageScreen> {
  static const _curriculum = 'Curriculum';
  static const _entranceExam = 'Entrance Exam';

  final _formKey = GlobalKey<FormState>();

  final _unitNumberController = TextEditingController();
  final _unitNameController = TextEditingController();
  final _examYearController = TextEditingController();

  final _questionPackageService = QuestionPackageService();

  String _packageType = _curriculum;

  String _selectedGrade = 'Grade 9';

  String _selectedStream = 'General';

  String _selectedSubject = 'Mathematics';

  String _selectedExamType = 'School Exam';

  bool _isSaving = false;

  bool get _isEntrancePackage => _packageType == _entranceExam;

  // ============================================================
  // STREAM OPTIONS
  // ============================================================

  List<String> get _streamOptions {
    if (_isEntrancePackage) {
      return const ['Entrance'];
    }

    if (_selectedGrade == 'Grade 11' || _selectedGrade == 'Grade 12') {
      return const ['Natural Science', 'Social Science'];
    }

    return const ['General'];
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _unitNumberController.dispose();
    _unitNameController.dispose();
    _examYearController.dispose();
    super.dispose();
  }

  // ============================================================
  // CREATE PACKAGE
  // ============================================================

  Future<void> _createPackage() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _questionPackageService.createDraftPackage(
        grade: _selectedGrade,
        stream: _selectedStream,
        subject: _selectedSubject,
        unitNumber: int.parse(_unitNumberController.text.trim()),
        unitName: _unitNameController.text.trim(),
        examType: _selectedExamType,
        examYear: _examYearController.text.trim().isEmpty
            ? null
            : int.parse(_examYearController.text.trim()),
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft package created successfully.')),
      );

      Navigator.of(context).pop();
    } catch (error) {
      debugPrint('CREATE PACKAGE ERROR: $error');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to create the package. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // VALIDATORS
  // ============================================================

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }

    return null;
  }

  String? _unitNumberValidator(String? value) {
    final unitNumber = int.tryParse(value?.trim() ?? '');

    final minimumUnitNumber = _isEntrancePackage ? 0 : 1;

    if (unitNumber == null || unitNumber < minimumUnitNumber) {
      return 'Enter a valid unit number.';
    }

    return null;
  }

  String? _examYearValidator(String? value) {
    if (_isEntrancePackage && (value == null || value.trim().isEmpty)) {
      return 'Exam year is required for entrance packages.';
    }

    if (value != null &&
        value.trim().isNotEmpty &&
        int.tryParse(value.trim()) == null) {
      return 'Enter a valid year.';
    }

    return null;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Package')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Text(
                'Question Package',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                'Create a draft package before assigning questions.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),

              const SizedBox(height: 28),

              _sectionTitle('Package Information'),

              const SizedBox(height: 14),

              _buildDropdown(
                label: 'Package Type',
                value: _packageType,
                items: const [_curriculum, _entranceExam],
                onChanged: (value) {
                  setState(() {
                    _packageType = value!;

                    if (_isEntrancePackage) {
                      _selectedGrade = 'Entrance';
                      _selectedStream = 'Entrance';
                    } else {
                      _selectedGrade = 'Grade 9';
                      _selectedStream = 'General';
                    }
                  });
                },
              ),

              const SizedBox(height: 14),

              _buildDropdown(
                label: 'Grade',
                value: _selectedGrade,
                items: _isEntrancePackage
                    ? const ['Entrance']
                    : const ['Grade 9', 'Grade 10', 'Grade 11', 'Grade 12'],
                onChanged: (value) {
                  setState(() {
                    _selectedGrade = value!;

                    if (_selectedGrade == 'Grade 11' ||
                        _selectedGrade == 'Grade 12') {
                      _selectedStream = 'Natural Science';
                    } else {
                      _selectedStream = 'General';
                    }
                  });
                },
              ),

              const SizedBox(height: 14),

              _buildDropdown(
                label: 'Stream',
                value: _selectedStream,
                items: _streamOptions,
                onChanged: (value) {
                  setState(() {
                    _selectedStream = value!;
                  });
                },
              ),

              const SizedBox(height: 14),

              _buildDropdown(
                label: 'Subject',
                value: _selectedSubject,
                items: const [
                  'Mathematics',
                  'Physics',
                  'Chemistry',
                  'Biology',
                  'English',
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedSubject = value!;
                  });
                },
              ),

              const SizedBox(height: 28),

              _sectionTitle('Unit and Exam Information'),

              const SizedBox(height: 14),

              _buildTextField(
                controller: _unitNumberController,
                label: 'Unit Number',
                hint: _isEntrancePackage ? 'Example: 0' : 'Example: 1',
                keyboardType: TextInputType.number,
                validator: _unitNumberValidator,
              ),

              const SizedBox(height: 14),

              _buildTextField(
                controller: _unitNameController,
                label: 'Unit Name',
                hint: _isEntrancePackage ? 'Example: General' : 'Example: Sets',
                validator: _requiredValidator,
              ),

              const SizedBox(height: 14),

              _buildDropdown(
                label: 'Exam Type',
                value: _selectedExamType,
                items: const [
                  'Entrance Exam',
                  'Model Exam',
                  'School Exam',
                  'Mock Exam',
                  'Other',
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedExamType = value!;
                  });
                },
              ),

              const SizedBox(height: 14),

              _buildTextField(
                controller: _examYearController,
                label: 'Exam Year${_isEntrancePackage ? '' : ' (Optional)'}',
                hint: 'Example: 2026',
                keyboardType: TextInputType.number,
                validator: _examYearValidator,
              ),

              const SizedBox(height: 28),

              _sectionTitle('Version'),

              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('Version 1'),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _createPackage,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_box_outlined),
                  label: Text(
                    _isSaving ? 'Creating...' : 'Create Draft Package',
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
    );
  }
}
