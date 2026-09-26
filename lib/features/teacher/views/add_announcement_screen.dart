import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../announcements/models/announcement.dart';
import '../../announcements/providers/announcement_providers.dart';

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

      // Send Push Notification
      try {
        await ref.read(notificationServiceProvider).sendPushNotification(
          schoolCode: schoolId,
          title: _isPriority ? '🚨 إعلان مدرسي هام: ${_titleController.text.trim()}' : '📢 إعلان مدرسي: ${_titleController.text.trim()}',
          message: _contentController.text.trim(),
        );
      } catch (_) {}

      if (!mounted) return;
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
      Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('نشر إعلان جديد'),
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
                  child: Form(
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
                          maxLines: 6,
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
                        const SizedBox(height: 32),

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
                ),
              ),
            ),
    );
  }
}