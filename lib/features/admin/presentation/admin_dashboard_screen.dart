import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/user_role.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../books/data/book_model.dart';
import '../../books/data/book_service.dart';
import '../../notifications/data/notification_model.dart';
import '../../notifications/data/notification_service.dart';
import '../../past_entrance_exams/data/past_exam_model.dart';
import '../../past_entrance_exams/data/past_exam_service.dart';
import '../../practice/data/models/question_package_model.dart';
import '../../practice/data/question_model.dart';
import '../data/admin_analytics_service.dart';
import '../data/admin_monitoring_service.dart';
import '../data/admin_question_service.dart';
import '../data/admin_service.dart';
import '../data/admin_settings_service.dart';
import '../data/admin_student_service.dart';
import '../data/audit_service.dart';
import '../data/models/payment_model.dart';
import '../data/payment_service.dart';
import '../data/question_package_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedTabIndex = 0;
  UserRole _currentRole = UserRole.admin;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final role = await AdminService.getCurrentRole();
    if (mounted) {
      setState(() {
        _currentRole = role;
        _isLoadingRole = false;
      });
    }
  }

  final List<String> _tabTitles = const [
    'Overview',
    'Students',
    'Payments',
    'Content',
    'Monitoring',
    'Announcements',
    'Analytics',
    'Audit Logs',
    'Admin Management',
    'Settings',
  ];

  final List<IconData> _tabIcons = const [
    Icons.dashboard_rounded,
    Icons.people_alt_rounded,
    Icons.payments_rounded,
    Icons.library_books_rounded,
    Icons.insights_rounded,
    Icons.campaign_rounded,
    Icons.analytics_rounded,
    Icons.history_rounded,
    Icons.admin_panel_settings_rounded,
    Icons.settings_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'EduRise Admin',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _currentRole.isFounder ? Colors.amber.shade700 : AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _currentRole.isFounder ? 'FOUNDER' : 'ADMIN',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Student View',
            icon: const Icon(Icons.exit_to_app_rounded),
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
      drawer: _buildNavigationDrawer(),
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          _OverviewView(
            onNavigateTab: (index) => setState(() => _selectedTabIndex = index),
          ),
          const _StudentsView(),
          const _PaymentsView(),
          const _ContentView(),
          const _MonitoringView(),
          const _AnnouncementsView(),
          const _AnalyticsView(),
          const _AuditLogsView(),
          _AdminManagementView(isFounder: _currentRole.isFounder),
          const _SettingsView(),
        ],
      ),
    );
  }

  Widget _buildNavigationDrawer() {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    _currentRole.isFounder ? Colors.indigo.shade900 : AppColors.primaryDark,
                  ],
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        _currentRole.isFounder
                            ? Icons.verified_user_rounded
                            : Icons.admin_panel_settings_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      AdminService.currentUserEmail ?? 'Administrator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _currentRole.isFounder ? 'Primary Founder' : 'Operational Admin',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _tabTitles.length,
                itemBuilder: (context, index) {
                  final isSelected = _selectedTabIndex == index;
                  final isFounderOnly = index == 8; // Admin Management

                  return ListTile(
                    selected: isSelected,
                    selectedTileColor: AppColors.primary.withOpacity(0.12),
                    leading: Icon(
                      _tabIcons[index],
                      color: isSelected
                          ? AppColors.primary
                          : (isFounderOnly && !_currentRole.isFounder ? Colors.grey : null),
                    ),
                    title: Row(
                      children: [
                        Text(
                          _tabTitles[index],
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isFounderOnly && !_currentRole.isFounder ? Colors.grey : null,
                          ),
                        ),
                        if (isFounderOnly && _currentRole.isFounder) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade700,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'FOUNDER',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() => _selectedTabIndex = index);
                    },
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('Return to Student App'),
              onTap: () {
                Navigator.of(context).pop();
                context.go('/home');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: () async {
                Navigator.of(context).pop();
                AdminService.clearCache();
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 1. OVERVIEW VIEW
// ============================================================================

class _OverviewView extends StatefulWidget {
  final ValueChanged<int> onNavigateTab;

  const _OverviewView({required this.onNavigateTab});

  @override
  State<_OverviewView> createState() => _OverviewViewState();
}

class _OverviewViewState extends State<_OverviewView> {
  final AdminAnalyticsService _analyticsService = AdminAnalyticsService();
  final PaymentService _paymentService = PaymentService();
  late Future<AdminAnalyticsData> _analyticsFuture;
  late Future<List<PaymentSubmission>> _pendingPaymentsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _analyticsFuture = _analyticsService.getAnalyticsData();
    _pendingPaymentsFuture = _paymentService.getSubmissions(statusFilter: 'pending', limit: 5);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _loadData());
        await _analyticsFuture;
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pending Payments Alert Banner
          FutureBuilder<List<PaymentSubmission>>(
            future: _pendingPaymentsFuture,
            builder: (context, snapshot) {
              final pendingList = snapshot.data ?? [];
              if (pendingList.isEmpty) return const SizedBox.shrink();

              return Card(
                elevation: 0,
                color: Colors.amber.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.amber.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.notification_important_rounded, color: Colors.amber.shade900, size: 30),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${pendingList.length} Pending Payment(s)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Colors.amber.shade900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Students have submitted payment receipts awaiting review.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => widget.onNavigateTab(2), // Navigate to Payments
                        child: const Text('Review'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          const Text(
            'Operations Summary',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          FutureBuilder<AdminAnalyticsData>(
            future: _analyticsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Unable to load metrics: ${snapshot.error}'));
              }

              final d = snapshot.data!;
              return GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.35,
                children: [
                  _buildMetricCard(
                    title: 'Total Students',
                    value: '${d.totalStudents}',
                    subtitle: '${d.paidStudents} paid access',
                    icon: Icons.people_alt_rounded,
                    color: AppColors.primary,
                    onTap: () => widget.onNavigateTab(1),
                  ),
                  _buildMetricCard(
                    title: 'Pending Reviews',
                    value: '${d.pendingPayments}',
                    subtitle: 'Requires action',
                    icon: Icons.pending_actions_rounded,
                    color: Colors.orange.shade700,
                    onTap: () => widget.onNavigateTab(2),
                  ),
                  _buildMetricCard(
                    title: 'Total Revenue',
                    value: '${d.totalRevenue.toStringAsFixed(0)} ETB',
                    subtitle: '${d.approvedPayments} approved',
                    icon: Icons.account_balance_wallet_rounded,
                    color: Colors.green.shade700,
                    onTap: () => widget.onNavigateTab(6),
                  ),
                  _buildMetricCard(
                    title: 'Questions Library',
                    value: '${d.totalQuestions}',
                    subtitle: '${d.totalPackages} packages',
                    icon: Icons.quiz_rounded,
                    color: Colors.purple.shade700,
                    onTap: () => widget.onNavigateTab(3),
                  ),
                  _buildMetricCard(
                    title: 'Book Units',
                    value: '${d.totalBookUnits}',
                    subtitle: 'In digital library',
                    icon: Icons.menu_book_rounded,
                    color: Colors.teal.shade700,
                    onTap: () => widget.onNavigateTab(3),
                  ),
                  _buildMetricCard(
                    title: 'System Logs',
                    value: 'Audit Trail',
                    subtitle: 'Security history',
                    icon: Icons.security_rounded,
                    color: Colors.blueGrey.shade700,
                    onTap: () => widget.onNavigateTab(7),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Quick Action Shortcuts
          const Text(
            'Quick Content Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/admin/add-question'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Question'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/admin/books/upload'),
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('Upload Book'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/admin/create-package'),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Create Package'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/admin/past-exams/upload'),
                  icon: const Icon(Icons.history_edu_rounded),
                  label: const Text('Upload Exam'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  Icon(icon, color: color, size: 20),
                ],
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. STUDENTS VIEW
// ============================================================================

class _StudentsView extends StatefulWidget {
  const _StudentsView();

  @override
  State<_StudentsView> createState() => _StudentsViewState();
}

class _StudentsViewState extends State<_StudentsView> {
  final AdminStudentService _studentService = AdminStudentService();
  final TextEditingController _searchController = TextEditingController();

  String _statusFilter = 'all';
  String _gradeFilter = 'all';
  List<StudentSummary> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    try {
      final list = await _studentService.getStudents(
        searchQuery: _searchController.text,
        gradeFilter: _gradeFilter,
        statusFilter: _statusFilter,
      );
      if (mounted) {
        setState(() {
          _students = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showStudentDetails(StudentSummary student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _StudentDetailSheet(
        student: student,
        onAccessChanged: () => _fetchStudents(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by student name or email...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _fetchStudents();
                },
              ),
            ),
            onSubmitted: (_) => _fetchStudents(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  decoration: const InputDecoration(labelText: 'Status', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Access')),
                    DropdownMenuItem(value: 'paid', child: Text('Paid Access')),
                    DropdownMenuItem(value: 'unpaid', child: Text('Locked / Free')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      _statusFilter = val;
                      _fetchStudents();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _gradeFilter,
                  decoration: const InputDecoration(labelText: 'Grade', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Grades')),
                    DropdownMenuItem(value: 'Grade 9', child: Text('Grade 9')),
                    DropdownMenuItem(value: 'Grade 10', child: Text('Grade 10')),
                    DropdownMenuItem(value: 'Grade 11', child: Text('Grade 11')),
                    DropdownMenuItem(value: 'Grade 12', child: Text('Grade 12')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      _gradeFilter = val;
                      _fetchStudents();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _students.isEmpty
                  ? const Center(child: Text('No students match criteria.'))
                  : RefreshIndicator(
                      onRefresh: _fetchStudents,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _students.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final s = _students[index];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S'),
                              ),
                              title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${s.email}\n${s.grade} • ${s.stream}'),
                              isThreeLine: true,
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: s.isPaid ? AppColors.success.withOpacity(0.12) : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  s.isPaid ? 'PAID' : 'FREE',
                                  style: TextStyle(
                                    color: s.isPaid ? AppColors.success : Colors.grey.shade700,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              onTap: () => _showStudentDetails(s),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

class _StudentDetailSheet extends StatefulWidget {
  final StudentSummary student;
  final VoidCallback onAccessChanged;

  const _StudentDetailSheet({required this.student, required this.onAccessChanged});

  @override
  State<_StudentDetailSheet> createState() => _StudentDetailSheetState();
}

class _StudentDetailSheetState extends State<_StudentDetailSheet> {
  final AdminStudentService _studentService = AdminStudentService();
  late Future<Map<String, dynamic>> _detailsFuture;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _studentService.getStudentDetails(widget.student.uid);
  }

  Future<void> _toggleAccess(bool currentPaid) async {
    setState(() => _isToggling = true);
    try {
      await _studentService.toggleStudentPaidAccess(widget.student.uid, !currentPaid);
      widget.onAccessChanged();
      if (mounted) {
        setState(() {
          _detailsFuture = _studentService.getStudentDetails(widget.student.uid);
          _isToggling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(!currentPaid ? 'Paid access granted.' : 'Access revoked.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isToggling = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollController) {
        return FutureBuilder<Map<String, dynamic>>(
          future: _detailsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data ?? {};
            final student = (data['profile'] as StudentSummary?) ?? widget.student;
            final practice = data['practice'] as Map<String, dynamic>? ?? {};
            final studyPlan = data['studyPlan'] as Map<String, dynamic>? ?? {};
            final payments = (data['payments'] as List<PaymentSubmission>?) ?? [];

            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Text(student.name.isNotEmpty ? student.name[0].toUpperCase() : 'S', style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(student.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(student.email, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          Text('${student.grade} • ${student.stream}', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Access Control Switch
                Card(
                  elevation: 0,
                  color: student.isPaid ? AppColors.success.withOpacity(0.08) : Colors.grey.shade100,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: SwitchListTile(
                    title: const Text('Paid Access Entitlement', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(student.isPaid ? 'Active (All features unlocked)' : 'Locked (Restricted to free content)'),
                    value: student.isPaid,
                    onChanged: _isToggling ? null : (val) => _toggleAccess(student.isPaid),
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Learning Metrics', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildStatChip('Practice Sessions', '${practice['sessionsCount'] ?? 0}'),
                    const SizedBox(width: 8),
                    _buildStatChip('Accuracy', '${practice['accuracy'] ?? 0}%'),
                    const SizedBox(width: 8),
                    _buildStatChip('Study Tasks Done', '${studyPlan['completedTasks'] ?? 0}/${studyPlan['totalTasks'] ?? 0}'),
                  ],
                ),
                const SizedBox(height: 20),

                const Text('Payment History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (payments.isEmpty)
                  const Text('No payment submissions recorded for this student.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))
                else
                  ...payments.map((p) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          p.isApproved ? Icons.check_circle : (p.isPending ? Icons.hourglass_top : Icons.cancel),
                          color: p.isApproved ? AppColors.success : (p.isPending ? Colors.orange : AppColors.error),
                        ),
                        title: Text('${p.amount.toStringAsFixed(0)} ETB via ${p.paymentMethod}'),
                        subtitle: Text('Ref: ${p.transactionReference}\n${p.submittedAt?.toString().substring(0, 16) ?? ''}'),
                        trailing: Text(p.status.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      )),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 3. PAYMENTS VIEW (CRITICAL WORKFLOW)
// ============================================================================

class _PaymentsView extends StatefulWidget {
  const _PaymentsView();

  @override
  State<_PaymentsView> createState() => _PaymentsViewState();
}

class _PaymentsViewState extends State<_PaymentsView> with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PaymentListTab(status: 'pending', service: _paymentService),
          _PaymentListTab(status: 'approved', service: _paymentService),
          _PaymentListTab(status: 'rejected', service: _paymentService),
        ],
      ),
    );
  }
}

class _PaymentListTab extends StatefulWidget {
  final String status;
  final PaymentService service;

  const _PaymentListTab({required this.status, required this.service});

  @override
  State<_PaymentListTab> createState() => _PaymentListTabState();
}

class _PaymentListTabState extends State<_PaymentListTab> {
  late Future<List<PaymentSubmission>> _submissionsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _submissionsFuture = widget.service.getSubmissions(statusFilter: widget.status);
  }

  void _openReviewModal(PaymentSubmission submission) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _PaymentReviewSheet(
        submission: submission,
        service: widget.service,
        onReviewed: () {
          setState(() => _load());
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(() => _load());
        await _submissionsFuture;
      },
      child: FutureBuilder<List<PaymentSubmission>>(
        future: _submissionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading payments: ${snapshot.error}'));
          }

          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 54, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No ${widget.status} payments.', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = list[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AppColors.border),
                ),
                child: InkWell(
                  onTap: () => _openReviewModal(item),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                item.studentName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${item.amount.toStringAsFixed(0)} ETB',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${item.studentEmail} • ${item.studentGrade}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Method: ${item.paymentMethod}', style: const TextStyle(fontSize: 12)),
                            Text('Ref: ${item.transactionReference}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Submitted: ${item.submittedAt?.toString().substring(0, 16) ?? 'recent'}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _PaymentReviewSheet extends StatefulWidget {
  final PaymentSubmission submission;
  final PaymentService service;
  final VoidCallback onReviewed;

  const _PaymentReviewSheet({required this.submission, required this.service, required this.onReviewed});

  @override
  State<_PaymentReviewSheet> createState() => _PaymentReviewSheetState();
}

class _PaymentReviewSheetState extends State<_PaymentReviewSheet> {
  final _rejectionController = TextEditingController();
  bool _isProcessing = false;

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve Payment?'),
        content: Text('Approve ${widget.submission.amount.toStringAsFixed(0)} ETB payment for ${widget.submission.studentName}? This will unlock paid access immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      await widget.service.approvePayment(widget.submission.id);
      if (!mounted) return;
      widget.onReviewed();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment approved! Student access unlocked.'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reject Payment Submission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason so the student can correct their submission:'),
            const SizedBox(height: 12),
            TextField(
              controller: _rejectionController,
              decoration: const InputDecoration(hintText: 'e.g. Reference number not found or screenshot blurry'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, _rejectionController.text.trim()),
            child: const Text('Reject Submission'),
          ),
        ],
      ),
    );

    if (reason == null) return;

    setState(() => _isProcessing = true);
    try {
      await widget.service.rejectPayment(submissionId: widget.submission.id, rejectionReason: reason);
      if (!mounted) return;
      widget.onReviewed();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment marked as rejected and student notified.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (_, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Review Payment: ${s.studentName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${s.studentEmail} • ${s.studentGrade} ${s.studentStream}', style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),

            // Metadata card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildRow('Amount', '${s.amount.toStringAsFixed(0)} ETB'),
                    const Divider(height: 12),
                    _buildRow('Method', s.paymentMethod),
                    const Divider(height: 12),
                    _buildRow('Tx Reference', s.transactionReference),
                    const Divider(height: 12),
                    _buildRow('Status', s.status.toUpperCase()),
                    if (s.rejectionReason != null) ...[
                      const Divider(height: 12),
                      _buildRow('Rejection Reason', s.rejectionReason!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Receipt image preview
            const Text('Uploaded Receipt / Proof:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            if (s.receiptUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  s.receiptUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 120,
                    color: Colors.grey.shade200,
                    child: const Center(child: Text('Unable to load receipt preview.')),
                  ),
                ),
              )
            else
              const Text('No receipt image URL provided.', style: TextStyle(color: AppColors.error)),
            const SizedBox(height: 24),

            // Actions for Pending submissions
            if (s.isPending) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _isProcessing ? null : _reject,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('REJECT'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _isProcessing ? null : _approve,
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('APPROVE'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        const SizedBox(width: 12),
        Flexible(
          child: SelectableText(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 4. CONTENT MANAGEMENT VIEW (QUESTIONS, PACKAGES, BOOKS, EXAMS)
// ============================================================================

class _ContentView extends StatefulWidget {
  const _ContentView();

  @override
  State<_ContentView> createState() => _ContentViewState();
}

class _ContentViewState extends State<_ContentView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Questions'),
            Tab(text: 'Packages'),
            Tab(text: 'Books'),
            Tab(text: 'Past Exams'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ContentQuestionsTab(),
          _ContentPackagesTab(),
          _ContentBooksTab(),
          _ContentPastExamsTab(),
        ],
      ),
    );
  }
}

class _ContentQuestionsTab extends StatefulWidget {
  const _ContentQuestionsTab();

  @override
  State<_ContentQuestionsTab> createState() => _ContentQuestionsTabState();
}

class _ContentQuestionsTabState extends State<_ContentQuestionsTab> {
  final AdminQuestionService _questionService = AdminQuestionService();
  String _selectedGrade = 'all';
  String _selectedSubject = 'all';
  String _selectedStatus = 'all';
  List<Question> _questions = [];
  final Set<String> _selectedQuestionIds = {};
  bool _isLoading = true;
  bool _isBatchProcessing = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _selectedQuestionIds.clear();
    });
    try {
      final list = await _questionService.getAdminQuestions(
        grade: _selectedGrade,
        subject: _selectedSubject,
        status: _selectedStatus,
      );
      if (mounted) {
        setState(() {
          _questions = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading questions: $e')),
        );
      }
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      await _questionService.updateQuestionStatus(id, newStatus);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == 'published'
                ? 'Question published successfully.'
                : 'Question moved to $newStatus.',
          ),
        ),
      );
      _fetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  Future<void> _bulkUpdateStatus(String newStatus) async {
    if (_selectedQuestionIds.isEmpty) return;

    final actionLabel = newStatus == 'published' ? 'Publish' : 'Unpublish';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$actionLabel ${_selectedQuestionIds.length} Questions?'),
        content: Text(
          'Are you sure you want to change status to "$newStatus" for ${_selectedQuestionIds.length} selected questions?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isBatchProcessing = true);
    try {
      final count = await _questionService.updateMultipleQuestionsStatus(
        _selectedQuestionIds.toList(),
        newStatus,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully updated $count questions to $newStatus.')),
      );
      _fetch();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Batch operation failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isBatchProcessing = false);
      }
    }
  }

  Future<void> _deleteQuestion(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Question?'),
        content: const Text('Are you sure you want to delete this question? This action will be logged in the audit trail.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _questionService.deleteQuestion(id);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final allSelected = _questions.isNotEmpty && _selectedQuestionIds.length == _questions.length;

    return Column(
      children: [
        // 1. FILTER CONTROLS & ADD / IMPORT BUTTONS
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Grade filter
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedGrade,
                      decoration: const InputDecoration(
                        labelText: 'Grade',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Grades')),
                        DropdownMenuItem(value: 'Grade 9', child: Text('Grade 9')),
                        DropdownMenuItem(value: 'Grade 10', child: Text('Grade 10')),
                        DropdownMenuItem(value: 'Grade 11', child: Text('Grade 11')),
                        DropdownMenuItem(value: 'Grade 12', child: Text('Grade 12')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedGrade = v);
                          _fetch();
                        }
                      },
                    ),
                  ),

                  // Subject filter
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedSubject,
                      decoration: const InputDecoration(
                        labelText: 'Subject',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Subjects')),
                        DropdownMenuItem(value: 'Biology', child: Text('Biology')),
                        DropdownMenuItem(value: 'Chemistry', child: Text('Chemistry')),
                        DropdownMenuItem(value: 'Physics', child: Text('Physics')),
                        DropdownMenuItem(value: 'Mathematics', child: Text('Mathematics')),
                        DropdownMenuItem(value: 'English', child: Text('English')),
                        DropdownMenuItem(value: 'Economics', child: Text('Economics')),
                        DropdownMenuItem(value: 'Geography', child: Text('Geography')),
                        DropdownMenuItem(value: 'History', child: Text('History')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedSubject = v);
                          _fetch();
                        }
                      },
                    ),
                  ),

                  // Status filter
                  SizedBox(
                    width: 140,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All Status')),
                        DropdownMenuItem(value: 'published', child: Text('Published')),
                        DropdownMenuItem(value: 'review', child: Text('Review')),
                        DropdownMenuItem(value: 'draft', child: Text('Draft')),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedStatus = v);
                          _fetch();
                        }
                      },
                    ),
                  ),

                  // Action Buttons
                  FilledButton.icon(
                    onPressed: () async {
                      await context.push('/admin/add-question');
                      _fetch();
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Question'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await context.push('/admin/questions/import');
                      _fetch();
                    },
                    icon: const Icon(Icons.upload_file_outlined, size: 18),
                    label: const Text('Bulk Import'),
                  ),
                ],
              ),

              // 2. BULK SELECTION ACTION BAR
              if (_questions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: allSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedQuestionIds.addAll(_questions.map((q) => q.id));
                            } else {
                              _selectedQuestionIds.clear();
                            }
                          });
                        },
                      ),
                      Text(
                        _selectedQuestionIds.isEmpty
                            ? 'Select all (${_questions.length})'
                            : '${_selectedQuestionIds.length} selected',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const Spacer(),
                      if (_selectedQuestionIds.isNotEmpty) ...[
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green.shade100,
                            foregroundColor: Colors.green.shade800,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: _isBatchProcessing ? null : () => _bulkUpdateStatus('published'),
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Publish Selected', style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          onPressed: _isBatchProcessing ? null : () => _bulkUpdateStatus('draft'),
                          icon: const Icon(Icons.unpublished_outlined, size: 16),
                          label: const Text('Unpublish Selected', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // 3. QUESTIONS LIST VIEW
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _questions.isEmpty
                  ? const Center(child: Text('No questions found for selection.'))
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _questions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final q = _questions[index];
                        final isSelected = _selectedQuestionIds.contains(q.id);
                        final isPublished = q.status.toLowerCase() == 'published';
                        final isReview = q.status.toLowerCase() == 'review';

                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      onChanged: (checked) {
                                        setState(() {
                                          if (checked == true) {
                                            _selectedQuestionIds.add(q.id);
                                          } else {
                                            _selectedQuestionIds.remove(q.id);
                                          }
                                        });
                                      },
                                    ),
                                    Expanded(
                                      child: Text(
                                        '${q.grade} • ${q.subject} • Unit ${q.unitNumber} ${q.unitName.isNotEmpty ? "(${q.unitName})" : ""}',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Status Badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isPublished
                                            ? Colors.green.shade50
                                            : isReview
                                                ? Colors.orange.shade50
                                                : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isPublished
                                              ? Colors.green.shade400
                                              : isReview
                                                  ? Colors.orange.shade400
                                                  : Colors.grey.shade400,
                                        ),
                                      ),
                                      child: Text(
                                        q.status.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isPublished
                                              ? Colors.green.shade800
                                              : isReview
                                                  ? Colors.orange.shade800
                                                  : Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                      onPressed: () => _deleteQuestion(q.id),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    q.question,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Correct: ${q.correctAnswer}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (q.examYear > 0) ...[
                                        const SizedBox(width: 12),
                                        Text(
                                          'Year: ${q.examYear} EC',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                        ),
                                      ],
                                      const Spacer(),
                                      // Individual Publish/Unpublish button
                                      if (!isPublished)
                                        FilledButton.tonalIcon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: Colors.green.shade50,
                                            foregroundColor: Colors.green.shade800,
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                          ),
                                          onPressed: () => _updateStatus(q.id, 'published'),
                                          icon: const Icon(Icons.publish, size: 14),
                                          label: const Text('Publish', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        )
                                      else
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.orange.shade800,
                                            side: BorderSide(color: Colors.orange.shade300),
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                          ),
                                          onPressed: () => _updateStatus(q.id, 'draft'),
                                          icon: const Icon(Icons.unpublished_outlined, size: 14),
                                          label: const Text('Unpublish', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _ContentPackagesTab extends StatelessWidget {
  const _ContentPackagesTab();

  @override
  Widget build(BuildContext context) {
    final service = QuestionPackageService();

    return FutureBuilder<List<QuestionPackage>>(
      future: service.getPackages(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final packages = snapshot.data ?? [];

        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/admin/create-package'),
            icon: const Icon(Icons.add),
            label: const Text('New Package'),
          ),
          body: packages.isEmpty
              ? const Center(child: Text('No question packages created yet.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: packages.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final p = packages[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
                      child: ListTile(
                        title: Text(p.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${p.questionCount} Questions • Status: ${p.status.toUpperCase()}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/admin/question-packages/${p.packageId}'),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _ContentBooksTab extends StatefulWidget {
  const _ContentBooksTab();

  @override
  State<_ContentBooksTab> createState() => _ContentBooksTabState();
}

class _ContentBooksTabState extends State<_ContentBooksTab> {
  final BookService _bookService = BookService();
  List<BookUnit> _units = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _isLoading = true);
    final list = await _bookService.getAllUnits();
    if (mounted) {
      setState(() {
        _units = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUnit(String unitId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Book Unit?'),
        content: const Text('Are you sure you want to delete this book unit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _bookService.deleteUnit(unitId);
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/admin/books/upload');
          _fetch();
        },
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload Unit'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _units.isEmpty
              ? const Center(child: Text('No book units found in library.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: _units.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final u = _units[index];
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${u.unitNumber}')),
                        title: Text('Unit ${u.unitNumber}: ${u.unitName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${u.grade} • ${u.subject}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          onPressed: () => _deleteUnit(u.id),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _ContentPastExamsTab extends StatelessWidget {
  const _ContentPastExamsTab();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/past-exams/import'),
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Bulk Import Exams'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history_edu_rounded, size: 54, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text('Past Entrance Exams', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Manage past entrance exams, question sets, and year configurations.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.push('/admin/past-exams/upload'),
                    icon: const Icon(Icons.add),
                    label: const Text('Upload Exam (Manual)'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => context.push('/admin/past-exams/import'),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Bulk Import Exams'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 5. MONITORING VIEW (PRACTICE & STUDY PLAN)
// ============================================================================

class _MonitoringView extends StatelessWidget {
  const _MonitoringView();

  @override
  Widget build(BuildContext context) {
    final monitoring = AdminMonitoringService();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Operational Learning Monitoring', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        // Practice Aggregates Card
        FutureBuilder<Map<String, dynamic>>(
          future: monitoring.getPracticeAggregates(),
          builder: (context, snapshot) {
            final data = snapshot.data ?? {};
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.quiz_rounded, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Practice Performance Metrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _metric('Total Sessions', '${data['totalSessions'] ?? 0}')),
                        Expanded(child: _metric('Avg Score', '${data['averageScore'] ?? 0}%')),
                        Expanded(child: _metric('Questions Solved', '${data['totalQuestionsAnswered'] ?? 0}')),
                        Expanded(child: _metric('Accuracy', '${data['overallAccuracy'] ?? 0}%')),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        // Study Plan Aggregates
        FutureBuilder<Map<String, dynamic>>(
          future: monitoring.getStudyPlanAggregates(),
          builder: (context, snapshot) {
            final data = snapshot.data ?? {};
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calendar_month_rounded, color: Colors.teal),
                        SizedBox(width: 8),
                        Text('Study Plan Engagement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _metric('Tasks Created', '${data['totalTasks'] ?? 0}'),
                        _metric('Tasks Completed', '${data['completedTasks'] ?? 0}'),
                        _metric('Completion Rate', '${data['completionRate'] ?? 0}%'),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),

        const Text('Recent Practice Attempts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),

        FutureBuilder<List<Map<String, dynamic>>>(
          future: monitoring.getRecentPracticeAttempts(limit: 15),
          builder: (context, snapshot) {
            final attempts = snapshot.data ?? [];
            if (attempts.isEmpty) {
              return const Text('No recent practice attempts recorded.', style: TextStyle(color: AppColors.textSecondary));
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: attempts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final a = attempts[index];
                final score = a['score'] ?? 0;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: (score >= 70 ? AppColors.success : Colors.orange).withOpacity(0.12),
                    child: Text('$score%', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: score >= 70 ? AppColors.success : Colors.orange)),
                  ),
                  title: Text('${a['subject'] ?? 'Subject'} • Unit ${a['unitNumber'] ?? ''}'),
                  subtitle: Text('${a['grade'] ?? ''} • ${a['correctAnswers'] ?? 0}/${a['totalQuestions'] ?? 0} correct'),
                  trailing: Text(
                    (a['createdAt'] != null ? (a['createdAt'] as dynamic).toDate().toString().substring(5, 16) : ''),
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
        const SizedBox(height: 2),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ============================================================================
// 6. ANNOUNCEMENTS VIEW
// ============================================================================

class _AnnouncementsView extends StatefulWidget {
  const _AnnouncementsView();

  @override
  State<_AnnouncementsView> createState() => _AnnouncementsViewState();
}

class _AnnouncementsViewState extends State<_AnnouncementsView> {
  final NotificationService _notificationService = NotificationService();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _isSending = false;
  late Future<List<AppNotification>> _recentFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _recentFuture = _notificationService.getAdminRecentNotifications();
  }

  Future<void> _sendBroadcast() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter announcement title and message.')));
      return;
    }

    setState(() => _isSending = true);
    try {
      await _notificationService.broadcastAnnouncement(title: title, body: body);
      _titleController.clear();
      _bodyController.clear();
      if (mounted) {
        setState(() => _load());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement broadcasted to all students! 🎉'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.campaign_rounded, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Compose Announcement', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Announcement Title', hintText: 'e.g. New Mock Exam Available'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Message Body', hintText: 'Enter details for students...'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _isSending ? null : _sendBroadcast,
                    icon: _isSending ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                    label: const Text('Broadcast Announcement'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Recently Sent Announcements & Alerts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),

        FutureBuilder<List<AppNotification>>(
          future: _recentFuture,
          builder: (context, snapshot) {
            final list = snapshot.data ?? [];
            if (list.isEmpty) return const Text('No recent notifications sent.', style: TextStyle(color: AppColors.textSecondary));

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 12),
              itemBuilder: (context, index) {
                final item = list[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    child: const Icon(Icons.notifications_rounded, color: AppColors.primary, size: 20),
                  ),
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${item.body}\nTarget: ${item.userId == 'all' ? 'All Students' : item.userId}'),
                  trailing: Text(item.createdAt?.toString().substring(5, 16) ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

// ============================================================================
// 7. ANALYTICS VIEW
// ============================================================================

class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView();

  @override
  Widget build(BuildContext context) {
    final analyticsService = AdminAnalyticsService();

    return FutureBuilder<AdminAnalyticsData>(
      future: analyticsService.getAnalyticsData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading analytics: ${snapshot.error}'));
        }

        final d = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Operational & Financial Analytics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Revenue card
            Card(
              elevation: 0,
              color: AppColors.success.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppColors.success.withOpacity(0.4))),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text('Total Verified Revenue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text(
                      '${d.totalRevenue.toStringAsFixed(0)} ETB',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.success),
                    ),
                    const SizedBox(height: 6),
                    Text('${d.approvedPayments} verified submissions • ${d.pendingPayments} pending', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Grade distribution
            const Text('Student Grade Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: d.gradeDistribution.entries.map((entry) {
                    final pct = d.totalStudents > 0 ? (entry.value / d.totalStudents) : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text('${entry.value} (${(pct * 100).round()}%)', style: const TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(value: pct, backgroundColor: Colors.grey.shade200),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Payment Methods Breakdown
            const Text('Payment Methods Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: d.paymentMethodBreakdown.entries.map((e) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.payment_rounded, color: AppColors.primary),
                      title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Text('${e.value} submissions', style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// 8. AUDIT LOGS VIEW
// ============================================================================

class _AuditLogsView extends StatefulWidget {
  const _AuditLogsView();

  @override
  State<_AuditLogsView> createState() => _AuditLogsViewState();
}

class _AuditLogsViewState extends State<_AuditLogsView> {
  late Future<List<AuditLogEntry>> _logsFuture;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _logsFuture = AuditService.getAuditLogs(actionFilter: _filter);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Administrative Audit Trail', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _filter,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Actions')),
                  DropdownMenuItem(value: 'payment_approved', child: Text('Payment Approved')),
                  DropdownMenuItem(value: 'payment_rejected', child: Text('Payment Rejected')),
                  DropdownMenuItem(value: 'question_deleted', child: Text('Question Deleted')),
                  DropdownMenuItem(value: 'book_unit_added', child: Text('Book Added')),
                  DropdownMenuItem(value: 'book_unit_deleted', child: Text('Book Deleted')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _filter = v;
                      _load();
                    });
                  }
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<AuditLogEntry>>(
            future: _logsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final logs = snapshot.data ?? [];
              if (logs.isEmpty) {
                return const Center(child: Text('No audit log entries recorded.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final log = logs[index];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  log.action.replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10),
                                ),
                              ),
                              Text(
                                log.timestamp?.toString().substring(0, 16) ?? '',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Actor: ${log.actorEmail} (${log.actorRole})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          Text('Target: ${log.targetType} • ${log.targetId}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          if (log.metadata != null && log.metadata!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('Metadata: ${log.metadata}', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 9. ADMIN MANAGEMENT VIEW (FOUNDER ONLY)
// ============================================================================

class _AdminManagementView extends StatefulWidget {
  final bool isFounder;

  const _AdminManagementView({required this.isFounder});

  @override
  State<_AdminManagementView> createState() => _AdminManagementViewState();
}

class _AdminManagementViewState extends State<_AdminManagementView> {
  late Future<List<Map<String, dynamic>>> _adminsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _adminsFuture = AdminService.getAdmins();
  }

  Future<void> _addAdminModal() async {
    final emailController = TextEditingController();
    final nameController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Administrator'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 12),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email Address')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add Admin')),
        ],
      ),
    );

    if (result != true) return;

    try {
      await AdminService.addAdmin(email: emailController.text, name: nameController.text);
      setState(() => _load());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Admin added successfully.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isFounder) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_rounded, size: 54, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('Founder Authority Required', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'Only the primary founder (${AdminService.founderEmail}) can view, provision, or manage administrators.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAdminModal,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Admin'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _adminsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final admins = snapshot.data ?? [];

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: admins.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final admin = admins[index];
              final email = admin['email'] as String? ?? '';
              final name = admin['name'] as String? ?? 'Admin';
              final role = admin['role'] as String? ?? 'admin';
              final isActive = admin['isActive'] as bool? ?? true;
              final isPermanent = admin['isPermanent'] as bool? ?? false;
              final isPrimaryFounder = email.toLowerCase() == AdminService.founderEmail;

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isPrimaryFounder ? Colors.amber.shade100 : AppColors.primary.withOpacity(0.1),
                    child: Icon(
                      isPrimaryFounder ? Icons.star_rounded : Icons.admin_panel_settings_rounded,
                      color: isPrimaryFounder ? Colors.amber.shade800 : AppColors.primary,
                    ),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$email\nRole: ${role.toUpperCase()}'),
                  isThreeLine: true,
                  trailing: isPrimaryFounder || isPermanent
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                          child: const Text('PERMANENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.brown)),
                        )
                      : Switch(
                          value: isActive,
                          onChanged: (val) async {
                            await AdminService.setAdminActive(admin['id'], val);
                            setState(() => _load());
                          },
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// 10. SETTINGS VIEW
// ============================================================================

class _SettingsView extends StatefulWidget {
  const _SettingsView();

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  final AdminSettingsService _settingsService = AdminSettingsService();
  final _cbeController = TextEditingController();
  final _cbeNameController = TextEditingController();
  final _telebirrController = TextEditingController();
  final _priceController = TextEditingController();
  bool _maintenance = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await _settingsService.getSettings();
    if (mounted) {
      setState(() {
        _cbeController.text = s.cbeAccount;
        _cbeNameController.text = s.cbeAccountName;
        _telebirrController.text = s.telebirrNumber;
        _priceController.text = s.subscriptionPrice.toStringAsFixed(0);
        _maintenance = s.maintenanceMode;
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final updated = SystemSettings(
        cbeAccount: _cbeController.text.trim(),
        cbeAccountName: _cbeNameController.text.trim(),
        telebirrNumber: _telebirrController.text.trim(),
        subscriptionPrice: double.tryParse(_priceController.text.trim()) ?? 500.0,
        maintenanceMode: _maintenance,
        announcementBanner: '',
      );

      await _settingsService.updateSettings(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved successfully.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Payment & System Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),

        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Bank Account Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 14),
                TextField(
                  controller: _telebirrController,
                  decoration: const InputDecoration(labelText: 'Telebirr Account Number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cbeController,
                  decoration: const InputDecoration(labelText: 'CBE Account Number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _cbeNameController,
                  decoration: const InputDecoration(labelText: 'CBE Account Holder Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Subscription Fee (ETB)'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
          child: SwitchListTile(
            title: const Text('Maintenance Mode', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Temporarily alert students of scheduled updates'),
            value: _maintenance,
            onChanged: (val) => setState(() => _maintenance = val),
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.save_rounded),
            label: Text(_isSaving ? 'Saving Settings...' : 'Save Configuration'),
          ),
        ),
      ],
    );
  }
}
