import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../announcements/models/announcement.dart';
import '../../announcements/providers/announcement_providers.dart';
import 'teacher_dashboard_screen.dart';

class AddAnnouncementScreen extends ConsumerStatefulWidget {
  const AddAnnouncementScreen({super.key});

  @override
  ConsumerState<AddAnnouncementScreen> createState() => _AddAnnouncementScreenState();
}

class _AddAnnouncementScreenState extends ConsumerState<AddAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isPriority = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final localStorage = ref.read(localStorageServiceProvider);
      final schoolId = AppConstants.sanitizeSchoolId(localStorage.getSchoolCode());

      final announcement = Announcement(
        id: const Uuid().v4(),
        schoolId: schoolId,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        createdAt: DateTime.now(),
        priority: _isPriority,
        isDeleted: false,
      );

      await ref.read(announcementServiceProvider).addAnnouncement(announcement);
      ref.invalidate(announcementsProvider(schoolId));
      ref.invalidate(teacherStatsProvider);

      // Send Push Notification to all students of the school
      try {
        await ref.read(notificationServiceProvider).sendPushNotification(
          schoolCode: schoolId,
          title: _isPriority
              ? '🚨 إعلان مدرسي هام: ${_titleController.text.trim()}'
              : '📢 إعلان مدرسي: ${_titleController.text.trim()}',
          message: _contentController.text.trim(),
          additionalData: {'type': 'announcement'},
        );
      } catch (_) {}

      if (!mounted) return;
      _titleController.clear();
      _contentController.clear();
      setState(() => _isPriority = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text('تم نشر الإعلان بنجاح في لوحة المدرسة'),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ أثناء النشر: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAnnouncement(Announcement ann, String schoolId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف التبليغ', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('هل أنت متأكد من حذف التبليغ "${ann.title}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(announcementServiceProvider).deleteAnnouncement(ann.id, schoolId: schoolId);
      ref.invalidate(announcementsProvider(schoolId));
      ref.invalidate(teacherStatsProvider);
      if (mounted) {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final schoolId = AppConstants.sanitizeSchoolId(ref.watch(localStorageServiceProvider).getSchoolCode());
    final announcementsAsync = ref.watch(announcementsProvider(schoolId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('نشر وإدارة التبليغات'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'عنوان الإعلان',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _titleController,
                              decoration: const InputDecoration(
                                hintText: 'مثال: موعد الامتحانات الشهرية',
                                prefixIcon: Icon(Icons.title_rounded),
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'يرجى كتابة عنوان الإعلان' : null,
                            ),
                            const SizedBox(height: 20),

                            Text(
                              'تفاصيل التبليغ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _contentController,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                hintText: 'اكتب نص التبليغ أو التوجيهات المدرسية هنا بالتفصيل...',
                              ),
                              validator: (val) => val == null || val.trim().isEmpty ? 'يرجى كتابة نص الإعلان' : null,
                            ),
                            const SizedBox(height: 20),

                            Container(
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              ),
                              child: SwitchListTile(
                                title: const Text('إعلان عاجل وهام', style: TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: const Text('سيظهر مميزاً باللون الأحمر لتنبيه الطلاب وأولياء الأمور'),
                                value: _isPriority,
                                activeThumbColor: Colors.red,
                                onChanged: (val) => setState(() => _isPriority = val),
                              ),
                            ),
                            const SizedBox(height: 24),

                            ElevatedButton.icon(
                              onPressed: _submit,
                              icon: const Icon(Icons.send_rounded),
                              label: const Text('نشر التبليغ الآن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Divider(),
                      const SizedBox(height: 12),
                      const Row(
                        children: [
                          Icon(Icons.campaign_rounded, color: AppColors.primary, size: 22),
                          SizedBox(width: 8),
                          Text(
                            'التبليغات المنشورة حالياً',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      announcementsAsync.when(
                        data: (announcements) {
                          if (announcements.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Center(
                                child: Text('لا توجد تبليغات منشورة حالياً', style: TextStyle(color: Colors.grey)),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: announcements.length,
                            itemBuilder: (context, index) {
                              final ann = announcements[index];
                              return Card(
                                color: isDark ? AppColors.darkCard : Colors.white,
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: ann.priority
                                        ? Colors.red.withValues(alpha: 0.5)
                                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                                  ),
                                ),
                                child: ListTile(
                                  leading: Icon(
                                    ann.priority ? Icons.warning_amber_rounded : Icons.campaign_rounded,
                                    color: ann.priority ? Colors.red : AppColors.primary,
                                  ),
                                  title: Text(ann.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text(
                                    '${DateFormat('yyyy-MM-dd • hh:mm a').format(ann.createdAt).replaceAll('AM', 'ص').replaceAll('PM', 'م')}\n${ann.content}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  isThreeLine: true,
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                    tooltip: 'حذف التبليغ',
                                    onPressed: () => _deleteAnnouncement(ann, schoolId),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),
                        error: (e, _) => Text('خطأ: $e'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}