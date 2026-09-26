import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../announcements/providers/announcement_providers.dart';

class ManageCommentsScreen extends ConsumerWidget {
  const ManageCommentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolId = AppConstants.sanitizeSchoolId(ref.watch(localStorageServiceProvider).getSchoolCode());
    final announcementsAsync = ref.watch(announcementsProvider(schoolId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة تعليقات الطلاب'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: announcementsAsync.when(
        data: (announcements) {
          if (announcements.isEmpty) {
            return const Center(child: Text('لا توجد إعلانات لعرض تعليقاتها.'));
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
                  leading: const Icon(Icons.announcement_rounded, color: AppColors.primary),
                  title: Text(announcement.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    DateFormat('yyyy-MM-dd').format(announcement.createdAt),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  children: [
                    commentsAsync.when(
                      data: (comments) {
                        if (comments.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Text('لا توجد تعليقات على هذا الإعلان.'),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: comments.length,
                          separatorBuilder: (context, i) => Divider(
                            height: 1,
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                          itemBuilder: (context, i) {
                            final comment = comments[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                                child: const Icon(Icons.person, color: AppColors.secondary, size: 20),
                              ),
                              title: Text(comment.senderName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(comment.content),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('hh:mm a - yyyy-MM-dd').format(comment.createdAt),
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('حذف التعليق'),
                                      content: const Text('هل أنت متأكد من حذف هذا التعليق؟'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(ctx, true),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          child: const Text('حذف'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await ref.read(announcementServiceProvider).deleteComment(comment.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('تم حذف التعليق بنجاح')),
                                      );
                                    }
                                  }
                                },
                              ),
                            );
                          },
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
