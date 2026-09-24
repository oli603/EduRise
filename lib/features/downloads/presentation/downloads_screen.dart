import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/session_manager.dart';
import '../../../core/constants/app_subjects.dart';
import '../../../core/offline/download_manager.dart';
import '../../../core/offline/offline_storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../profile/data/profile_service.dart';

class DownloadsScreen extends StatefulWidget {
  final OfflineStorageService? storageService;
  final DownloadManager? downloadManager;
  final List<DownloadPackageRecord>? initialPackages;
  final int? initialStorageBytes;

  const DownloadsScreen({
    super.key,
    this.storageService,
    this.downloadManager,
    this.initialPackages,
    this.initialStorageBytes,
  });

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen>
    with SingleTickerProviderStateMixin {
  late final OfflineStorageService _storage;
  late final DownloadManager _downloadManager;

  late TabController _tabController;
  StreamSubscription<String>? _statusSubscription;

  bool _isLoading = true;
  int _totalStorageBytes = 0;
  List<DownloadPackageRecord> _allPackages = [];

  @override
  void initState() {
    super.initState();
    _storage = widget.storageService ?? OfflineStorageService();
    _downloadManager = widget.downloadManager ?? DownloadManager();
    _tabController = TabController(length: 3, vsync: this);

    if (widget.initialPackages != null || widget.initialStorageBytes != null) {
      _allPackages = widget.initialPackages ?? [];
      _totalStorageBytes = widget.initialStorageBytes ?? 0;
      _isLoading = false;
    } else {
      _loadData();
    }

    _statusSubscription = _downloadManager.onStatusChanged.listen((_) {
      if (mounted) {
        _loadData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    }
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? SessionManager.currentUid;
      final packages = await _storage.getAllPackages(uid: currentUid);
      final bytes = await _storage.getTotalStorageBytes();

      String currentStream = 'natural';
      try {
        final profile = await ProfileService().getProfile();
        if (profile != null && profile.stream.isNotEmpty) {
          currentStream = EduRiseSubjects.canonicalizeStream(profile.stream);
        }
      } catch (_) {}

      // Filter packages strictly to the authenticated student's stream:
      final filteredPackages = packages.where((p) {
        if (p.stream != null && p.stream!.trim().isNotEmpty) {
          return EduRiseSubjects.canonicalizeStream(p.stream) == currentStream;
        }
        return EduRiseSubjects.isSubjectAllowedForStream(p.subject, currentStream);
      }).toList();

      if (mounted) {
        setState(() {
          _allPackages = filteredPackages;
          _totalStorageBytes = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _confirmAndRemoveDownload(DownloadPackageRecord package) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Download'),
        content: Text(
          'Are you sure you want to remove "${package.title}" from your device? '
          'This will free up local storage. Your online progress and notes will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _downloadManager.removeDownload(package.id);
      await _loadData(silent: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${package.title}" from downloads.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openPackage(DownloadPackageRecord package) {
    if (package.packageType == 'book') {
      context.push(
        '/books?grade=${Uri.encodeComponent(package.grade ?? '')}&subject=${Uri.encodeComponent(package.subject)}',
      );
    } else if (package.packageType == 'practice') {
      context.push(
        '/practice?grade=${Uri.encodeComponent(package.grade ?? '')}&stream=${Uri.encodeComponent(package.stream ?? '')}&subject=${Uri.encodeComponent(package.subject)}&unitNumber=${package.unitNumber ?? 0}&unitName=${Uri.encodeComponent(package.unitName ?? '')}&examYear=${package.examYear ?? ''}',
      );
    } else if (package.packageType == 'past_exam') {
      final isMath = package.subject.trim().toLowerCase() == 'mathematics';
      final duration = isMath ? 180 : 120;
      final year = package.examYear?.toString() ?? package.extraData['year']?.toString() ?? '';
      final stream = package.stream ?? package.extraData['stream'] as String? ?? 'natural';
      final qCount = package.itemCount > 0 ? package.itemCount : (package.extraData['questionCount'] as int? ?? 50);
      context.push(
        '/past-entrance-exams/instructions?year=${Uri.encodeComponent(year)}&subject=${Uri.encodeComponent(package.subject)}&stream=${Uri.encodeComponent(stream)}&questionCount=$qCount&durationMinutes=$duration',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookPackages =
        _allPackages.where((p) => p.packageType == 'book').toList();
    final practicePackages =
        _allPackages.where((p) => p.packageType == 'practice').toList();
    final pastExamPackages =
        _allPackages.where((p) => p.packageType == 'past_exam').toList();

    return Scaffold(
      backgroundColor: context.eduColors.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Downloads',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _loadData(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _loadData(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // 1. STORAGE USAGE BANNER
                    // ==========================================
                    _buildStorageBanner(),

                    const SizedBox(height: AppSpacing.lg),

                    // ==========================================
                    // 2. DOWNLOADED CONTENT SECTION
                    // ==========================================
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Downloaded Content',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.eduColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_allPackages.length} package${_allPackages.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // TAB BAR
                    Container(
                      decoration: BoxDecoration(
                        color: context.eduColors.cardBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.eduColors.border),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: context.eduColors.textSecondary,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: AppColors.primary.withValues(alpha: 0.12),
                        ),
                        dividerColor: Colors.transparent,
                        tabs: [
                          Tab(text: 'Books (${bookPackages.length})'),
                          Tab(text: 'Practice (${practicePackages.length})'),
                          Tab(text: 'Past Exams (${pastExamPackages.length})'),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // TAB CONTENT
                    AnimatedBuilder(
                      animation: _tabController,
                      builder: (context, _) {
                        switch (_tabController.index) {
                          case 0:
                            return _buildPackageList(
                              packages: bookPackages,
                              type: 'Books',
                              emptySubtitle:
                                  'Download unit PDFs from the Books section to read offline anytime.',
                              icon: Icons.menu_book_rounded,
                            );
                          case 1:
                            return _buildPackageList(
                              packages: practicePackages,
                              type: 'Practice Questions',
                              emptySubtitle:
                                  'Download question packages to solve problems without an internet connection.',
                              icon: Icons.assignment_rounded,
                            );
                          case 2:
                            return _buildPackageList(
                              packages: pastExamPackages,
                              type: 'Past Entrance Exams',
                              emptySubtitle:
                                  'Download national entrance exams to practice under timed conditions offline.',
                              icon: Icons.history_edu_rounded,
                            );
                          default:
                            return const SizedBox.shrink();
                        }
                      },
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ==========================================
                    // 3. OFFLINE ACTIVITY SECTION
                    // ==========================================
                    _buildOfflineActivitySection(),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
    );
  }

  // ============================================================
  // STORAGE BANNER
  // ============================================================
  Widget _buildStorageBanner() {
    final formatted = OfflineStorageService.formatBytes(_totalStorageBytes);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.eduColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.eduColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sd_storage_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local Storage Used',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.eduColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatted,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: context.eduColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 14,
                  color: AppColors.success,
                ),
                SizedBox(width: 4),
                Text(
                  'Ready Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PACKAGE LIST & CARDS
  // ============================================================
  Widget _buildPackageList({
    required List<DownloadPackageRecord> packages,
    required String type,
    required String emptySubtitle,
    required IconData icon,
  }) {
    if (packages.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: context.eduColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.eduColors.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.eduColors.surfaceSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: context.eduColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No $type Downloaded',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.eduColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              emptySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.eduColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: packages.length,
      separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final pkg = packages[index];
        return _buildPackageCard(pkg);
      },
    );
  }

  Widget _buildPackageCard(DownloadPackageRecord package) {
    final progress = _downloadManager.getProgress(package.id);
    final sizeStr = OfflineStorageService.formatBytes(package.sizeBytes);

    IconData leadingIcon;
    Color iconColor;
    if (package.packageType == 'book') {
      leadingIcon = Icons.menu_book_rounded;
      iconColor = Colors.indigo;
    } else if (package.packageType == 'practice') {
      leadingIcon = Icons.quiz_rounded;
      iconColor = Colors.teal;
    } else {
      leadingIcon = Icons.history_edu_rounded;
      iconColor = Colors.deepOrange;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.eduColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.eduColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(leadingIcon, color: iconColor, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      package.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: context.eduColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (package.itemCount > 0)
                          _buildBadge(
                            package.packageType == 'book'
                                ? '${package.itemCount} Units'
                                : '${package.itemCount} Questions',
                          ),
                        if (package.sizeBytes > 0) _buildBadge(sizeStr),
                        if (package.status == 'downloaded')
                          _buildBadge(
                            'Downloaded',
                            color: AppColors.success,
                            isFilled: true,
                          )
                        else if (package.status == 'failed')
                          _buildBadge(
                            'Failed',
                            color: AppColors.error,
                            isFilled: true,
                          )
                        else if (package.status == 'updateAvailable')
                          _buildBadge(
                            'Update Available',
                            color: AppColors.warning,
                            isFilled: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // PROGRESS BAR IF DOWNLOADING
          if (package.status == 'downloading') ...[
            const SizedBox(height: AppSpacing.md),
            LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              backgroundColor: context.eduColors.border,
              color: AppColors.primary,
            ),
            const SizedBox(height: 4),
            Text(
              'Downloading... ${(progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                color: context.eduColors.textSecondary,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.sm),

          // ACTIONS ROW
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: BorderSide(color: context.eduColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 16),
                label: const Text('Remove'),
                onPressed: () => _confirmAndRemoveDownload(package),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open'),
                onPressed: () => _openPackage(package),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(
    String text, {
    Color? color,
    bool isFilled = false,
  }) {
    final colors = context.eduColors;
    final badgeColor = color ?? colors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isFilled ? badgeColor.withValues(alpha: 0.12) : colors.surfaceSubtle,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isFilled ? badgeColor.withValues(alpha: 0.3) : colors.border,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isFilled ? FontWeight.bold : FontWeight.w500,
          color: badgeColor,
        ),
      ),
    );
  }

  // ============================================================
  // OFFLINE ACTIVITY SECTION
  // ============================================================
  Widget _buildOfflineActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Offline Activity',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.eduColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'These features automatically adapt and work offline using your local learning data and downloaded content.',
          style: TextStyle(
            fontSize: 13,
            color: context.eduColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildActivityTile(
          title: 'Study Plan',
          subtitle: 'Review scheduled study tasks and track completion status',
          icon: Icons.calendar_month_rounded,
          iconColor: Colors.blue,
          route: '/study-plan',
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildActivityTile(
          title: 'Progress Tracking',
          subtitle: 'View local practice accuracy, streaks, and question stats',
          icon: Icons.trending_up_rounded,
          iconColor: Colors.green,
          route: '/progress',
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildActivityTile(
          title: 'Weak Areas Analysis',
          subtitle: 'Identify focus areas and missed questions from your attempts',
          icon: Icons.warning_amber_rounded,
          iconColor: Colors.orange,
          route: '/weak-areas',
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildActivityTile(
          title: 'Personalized Challenges',
          subtitle: 'Dynamic practice quizzes generated from downloaded question sets',
          icon: Icons.psychology_rounded,
          iconColor: Colors.purple,
          route: '/challenges',
        ),
      ],
    );
  }

  Widget _buildActivityTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String route,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.eduColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.eduColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: context.eduColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 10,
                            color: AppColors.success,
                          ),
                          SizedBox(width: 2),
                          Text(
                            'Offline Ready',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.eduColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: context.eduColors.textSecondary,
            ),
            onPressed: () => context.push(route),
          ),
        ],
      ),
    );
  }
}
