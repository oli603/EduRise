import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../notifications/data/notification_service.dart';

/// Modern, refined, and personalized header for the EduRise Home screen.
///
/// Features a compact contextual label ('WELCOME BACK'), dynamic student
/// identity, concise educational guidance line, and an integrated,
/// theme-aware notification action.
class GreetingSection extends StatelessWidget {
  final String studentName;
  final String? contextualLabel;
  final String? subtitle;
  final Stream<int>? unreadCountStream;

  const GreetingSection({
    super.key,
    required this.studentName,
    this.contextualLabel,
    this.subtitle,
    this.unreadCountStream,
  });

  Stream<int> _resolveNotificationStream() {
    if (unreadCountStream != null) return unreadCountStream!;
    try {
      if (Firebase.apps.isNotEmpty) {
        return NotificationService().streamUnreadCount();
      }
    } catch (_) {}
    return Stream.value(0);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    final resolvedContextualLabel = contextualLabel ?? 'WELCOME BACK';
    final resolvedSubtitle = subtitle ?? 'Ready to continue learning?';
    final displayName = studentName.contains('👋')
        ? studentName
        : '$studentName 👋';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ====================================================
            // CONTEXTUAL IDENTITY (LABEL & USER GREETING)
            // ====================================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    resolvedContextualLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: colors.isDark
                          ? AppColors.primaryForDark
                          : AppColors.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.headingLarge.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      height: 1.2,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: AppSpacing.md),

            // ====================================================
            // BALANCED NOTIFICATION ACTION (48dp Touch Target)
            // ====================================================
            StreamBuilder<int>(
              stream: _resolveNotificationStream(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;

                return Semantics(
                  button: true,
                  label: unreadCount > 0
                      ? 'Notifications, $unreadCount unread'
                      : 'Notifications',
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: colors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: colors.border.withValues(alpha: 0.8),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.isDark
                                    ? Colors.black.withValues(alpha: 0.25)
                                    : Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              onTap: () => context.push('/notifications'),
                              child: Center(
                                child: Icon(
                                  Icons.notifications_outlined,
                                  size: 22,
                                  color: colors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // UNREAD COUNT BADGE
                        if (unreadCount > 0)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1.5,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(AppRadius.full),
                                border: Border.all(
                                  color: colors.scaffoldBackground,
                                  width: 1.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  unreadCount > 99 ? '99+' : '$unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 5),

        // ====================================================
        // EDUCATIONAL GUIDANCE SUBTITLE
        // ====================================================
        Text(
          resolvedSubtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            color: colors.textSecondary,
            fontWeight: FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
