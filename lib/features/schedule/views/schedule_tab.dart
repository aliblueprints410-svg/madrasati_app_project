import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/schedule_providers.dart';

class ScheduleTab extends ConsumerWidget {
  const ScheduleTab({super.key});

  void _openFullScreen(BuildContext context, String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('جدول الحصص'),
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 5,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localStorage = ref.watch(localStorageServiceProvider);
    final classId = localStorage.getSelectedGrade();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (classId == null) {
      return const Scaffold(
        body: Center(child: Text('خطأ: لم يتم تحديد الصف الدراسي')),
      );
    }

    final scheduleAsync = ref.watch(classScheduleImageProvider(classId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('جدول الحصص الأسبوعي', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: scheduleAsync.when(
        data: (imageUrl) {
          if (imageUrl == null || imageUrl.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.calendar_month_outlined, size: 64, color: AppColors.primary.withOpacity(0.6)),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'لم يتم رفع جدول هذا الصف بعد',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ستقوم إدارة المدرسة أو المعلم المسؤول برفع الجدول قريباً.',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return Column(
            children: [
              // Hint bar
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  children: [
                    Icon(Icons.touch_app_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'يمكنك تكبير الجدول وتحريكه بإصبعين لتوضيح الحصص',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.fullscreen_rounded, size: 22, color: AppColors.primary),
                      tooltip: 'ملء الشاشة',
                      onPressed: () => _openFullScreen(context, imageUrl),
                    ),
                  ],
                ),
              ),

              // Interactive Image Container
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(20),
                    minScale: 0.8,
                    maxScale: 4.5,
                    child: Center(
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Center(
                          child: SpinKitFadingCube(
                            color: AppColors.primary,
                            size: 40.0,
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
                              SizedBox(height: 8),
                              Text('تعذر تحميل صورة الجدول', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => Center(
          child: SpinKitFadingCube(
            color: AppColors.primary,
            size: 40.0,
          ),
        ),
        error: (err, stack) => Center(child: Text('حدث خطأ أثناء جلب الجدول: $err')),
      ),
    ),
  ),
);
}
}
