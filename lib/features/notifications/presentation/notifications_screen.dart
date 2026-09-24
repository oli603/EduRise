import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/notification_model.dart';
import '../data/notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();
    final colors = context.eduColors;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: notificationService.streamMyNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load notifications.',
                style: TextStyle(color: colors.textSecondary),
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: colors.textMuted,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Notifications Yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'You are all caught up!',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = notifications[index];
              return _NotificationCard(
                notification: item,
                onTap: () {
                  if (!item.isRead) {
                    notificationService.markAsRead(item.id);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eduColors;
    IconData icon;
    Color iconColor;
    Color bgBadgeColor;

    switch (notification.type) {
      case 'payment_approved':
        icon = Icons.verified_rounded;
        iconColor = AppColors.success;
        bgBadgeColor = AppColors.success.withValues(alpha: 0.12);
        break;
      case 'payment_rejected':
        icon = Icons.error_outline_rounded;
        iconColor = AppColors.error;
        bgBadgeColor = AppColors.error.withValues(alpha: 0.12);
        break;
      case 'announcement':
        icon = Icons.campaign_rounded;
        iconColor = colors.primary;
        bgBadgeColor = colors.primary.withValues(alpha: 0.12);
        break;
      default:
        icon = Icons.notifications_rounded;
        iconColor = colors.primary;
        bgBadgeColor = colors.primary.withValues(alpha: 0.12);
    }

    final cardBg = notification.isRead
        ? colors.cardBackground
        : (colors.isDark
            ? colors.primary.withValues(alpha: 0.15)
            : colors.primary.withValues(alpha: 0.05));
    final borderCol = notification.isRead
        ? colors.border
        : colors.primary.withValues(alpha: 0.35);

    return Card(
      elevation: 0,
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderCol),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: bgBadgeColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.bold,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            height: 8,
                            width: 8,
                            decoration: BoxDecoration(
                              color: colors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      notification.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    if (notification.createdAt != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        notification.createdAt!.toString().substring(0, 16),
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
