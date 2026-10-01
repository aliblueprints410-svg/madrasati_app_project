import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../announcements/models/announcement.dart';
import '../../announcements/models/comment.dart';
import '../../announcements/providers/announcement_providers.dart';
import 'teacher_dashboard_screen.dart';

class ManageCommentsScreen extends ConsumerWidget {
  const ManageCommentsScreen({super.key});

  Future<void> _showReplyDialog(
    BuildContext context,
    WidgetRef ref, {
    required Announcement announcement,
    Comment? targetComment,
  }) async {
    final replyController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(Icons.reply_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                targetComment != null
                    ? 'الرد على ${targetComment.senderName}'
                    : 'إضافة رد أو توضيح للتبليغ',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (targetComment != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '"${targetComment.content}"',
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: replyController,
              maxLines: 3,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'اكتب رد الأستاذ هنا...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (replyController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('إرسال الرد'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (submitted == true && replyController.text.trim().isNotEmpty) {
      final text = replyController.text.trim();
      final replyContent = targetComment != null
          ? 'رداً على (${targetComment.senderName}):\n$text'
          : text;

      final replyComment = Comment(
        id: const Uuid().v4(),
        announcementId: announcement.id,
        senderName: 'الأستاذ 👨‍🏫',
        content: replyContent,
        createdAt: DateTime.now(),
      );

      await ref.read(announcementServiceProvider).addComment(replyComment);
      ref.invalidate(commentsProvider(announcement.id));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال الرد بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteAnnouncement(
    BuildContext context,
    WidgetRef ref, {
    required Announcement announcement,
    required String schoolId,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف التبليغ', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من حذف التبليغ "${announcement.title}" نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('حذف التبليغ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(announcementServiceProvider).deleteAnnouncement(
        announcement.id,
        schoolId: schoolId,
      );
      ref.invalidate(announcementsProvider(schoolId));
      ref.invalidate(teacherStatsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف التبليغ بنجاح'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = AppConstants.sanitizeSchoolId(ref.watch(localStorageServiceProvider).getSchoolCode());
    final announcementsAsync = ref.watch(announcementsProvider(schoolId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة التبليغات وتعليقات الطلاب'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(announcementsProvider(schoolId)),
          ),
        ],
      ),
      body: announcementsAsync.when(
        data: (announcements) {
          if (announcements.isEmpty) {
            return const Center(child: Text('لا توجد إعلانات أو تبليغات منشورة حالياً.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: announcements.length,
            itemBuilder: (context, index) {
              final announcement = announcements[index];
              final commentsAsync = ref.watch(commentsProvider(announcement.id));

              return Card(
                elevation: 0,
                color: isDark ? AppColors.darkCard : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: ExpansionTile(
                  initiallyExpanded: index == 0,
                  leading: Icon(
                    announcement.priority ? Icons.warning_amber_rounded : Icons.announcement_rounded,
                    color: announcement.priority ? Colors.red : AppColors.primary,
                  ),
                  title: Text(announcement.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'تاريخ النشر: ${DateFormat('yyyy-MM-dd • hh:mm a').format(announcement.createdAt).replaceAll('AM', 'ص').replaceAll('PM', 'م')}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                        tooltip: 'حذف التبليغ',
                        onPressed: () => _confirmDeleteAnnouncement(
                          context,
                          ref,
                          announcement: announcement,
                          schoolId: schoolId,
                        ),
                      ),
                      const Icon(Icons.expand_more_rounded),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          announcement.content,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.darkTextSecondary : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    commentsAsync.when(
                      data: (comments) {
                        return Column(
                          children: [
                            if (comments.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text('لا توجد تعليقات على هذا الإعلان بعد.'),
                              )
                            else
                              ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: comments.length,
                                separatorBuilder: (context, i) => Divider(
                                  height: 1,
                                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                ),
                                itemBuilder: (context, i) {
                                  final comment = comments[i];
                                  final isTeacherReply = comment.senderName.contains('الأستاذ') ||
                                      comment.senderName.contains('إدارة');

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: isTeacherReply
                                          ? AppColors.primary.withValues(alpha: 0.2)
                                          : AppColors.secondary.withValues(alpha: 0.2),
                                      child: Icon(
                                        isTeacherReply ? Icons.school_rounded : Icons.person,
                                        color: isTeacherReply ? AppColors.primary : AppColors.secondary,
                                        size: 20,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Text(
                                          comment.senderName,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isTeacherReply ? AppColors.primary : null,
                                          ),
                                        ),
                                        if (isTeacherReply) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'رد رسمي',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 4),
                                        Text(comment.content),
                                        const SizedBox(height: 4),
                                        Text(
                                          DateFormat('hh:mm a - yyyy-MM-dd').format(comment.createdAt),
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.reply_rounded, color: AppColors.primary),
                                          tooltip: 'الرد على التعليق',
                                          onPressed: () => _showReplyDialog(
                                            context,
                                            ref,
                                            announcement: announcement,
                                            targetComment: comment,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                          tooltip: 'حذف التعليق',
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('حذف التعليق'),
                                                content: const Text('هل أنت متأكد من حذف هذا التعليق؟'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx, false),
                                                    child: const Text('إلغاء'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(ctx, true),
                                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                    child: const Text('حذف'),
                                                  ),
                                                ],
                                              ),
                                            );

                                            if (confirm == true) {
                                              await ref.read(announcementServiceProvider).deleteComment(
                                                comment.id,
                                                announcementId: announcement.id,
                                              );
                                              ref.invalidate(commentsProvider(announcement.id));
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('تم حذف التعليق بنجاح')),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showReplyDialog(
                                    context,
                                    ref,
                                    announcement: announcement,
                                  ),
                                  icon: const Icon(Icons.add_comment_rounded, size: 18),
                                  label: const Text('إضافة رد أو توضيح من الأستاذ على هذا التبليغ'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                      loading: () => const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (err, _) => Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text('خطأ: $err'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('خطأ: $err')),
      ),
    );
  }
}
