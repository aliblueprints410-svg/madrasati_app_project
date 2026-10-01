import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/subject_visual_helper.dart';
import '../providers/schedule_providers.dart';

class ScheduleTab extends ConsumerStatefulWidget {
  const ScheduleTab({super.key});

  @override
  ConsumerState<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends ConsumerState<ScheduleTab> {
  String? _selectedDay;

  final List<String> _schoolWeekDays = const [
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _detectCurrentSchoolDay();
  }

  String _detectCurrentSchoolDay() {
    switch (DateTime.now().weekday) {
      case DateTime.sunday:
        return 'الأحد';
      case DateTime.monday:
        return 'الإثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.thursday:
        return 'الخميس';
      default:
        return 'الأحد'; // Default to Sunday on weekends
    }
  }

  bool _isToday(String day) {
    return day == _detectCurrentSchoolDay();
  }

  IconData _getSubjectIcon(String subject) => SubjectVisualHelper.getSubjectIcon(subject);

  Map<String, List<String>>? _tryParseTableData(String rawContent) {
    try {
      final trimmed = rawContent.trim();
      if (!trimmed.startsWith('{')) return null;
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        if (decoded['type'] == 'table' && decoded['data'] is Map) {
          final dataMap = decoded['data'] as Map;
          final result = <String, List<String>>{};
          dataMap.forEach((k, v) {
            if (v is List) {
              result[k.toString().trim()] =
                  v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
            }
          });
          return result.isNotEmpty ? result : null;
        }

        // Direct day map
        final result = <String, List<String>>{};
        decoded.forEach((k, v) {
          if (v is List) {
            result[k.toString().trim()] =
                v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
          }
        });
        if (result.keys.any((k) => k.contains('أحد') || k.contains('احد') || k.contains('إثنين') || k.contains('اربعاء') || k.contains('خميس') || k.contains('ثلاثاء'))) {
          return result;
        }
      }
    } catch (_) {}
    return null;
  }

  Widget _buildScheduleImageWidget(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64Str = imageUrl.split(',').last;
        final bytes = base64Decode(base64Str);
        return Image.memory(
          bytes,
          fit: BoxFit.contain,
        );
      } catch (_) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
              SizedBox(height: 8),
              Text('تعذر عرض صورة الجدول', style: TextStyle(color: Colors.red)),
            ],
          ),
        );
      }
    }

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.contain,
      placeholder: (context, url) => const Center(
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
    );
  }

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
              child: _buildScheduleImageWidget(imageUrl),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localStorage = ref.watch(localStorageServiceProvider);
    final classId = localStorage.getSelectedGrade();
    final gradeName = localStorage.getSelectedGradeName() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hPadding = Responsive.getHorizontalPadding(context);

    if (classId == null) {
      return const Scaffold(
        body: Center(child: Text('خطأ: لم يتم تحديد الصف الدراسي')),
      );
    }

    final scheduleAsync = ref.watch(classScheduleImageProvider(classId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('جدول الحصص الأسبوعي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            if (gradeName.isNotEmpty)
              Text(
                gradeName,
                style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث الجدول',
            onPressed: () => ref.invalidate(classScheduleImageProvider(classId)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: scheduleAsync.when(
            data: (rawContent) {
              if (rawContent == null || rawContent.isEmpty) {
                return _buildEmptyState(isDark);
              }

              final tableData = _tryParseTableData(rawContent);

              if (tableData != null && tableData.isNotEmpty) {
                return _buildInteractiveDashboard(tableData, isDark, hPadding);
              }

              return _buildImageView(rawContent, isDark);
            },
            loading: () => const Center(
              child: SpinKitFadingCube(
                color: AppColors.primary,
                size: 40.0,
              ),
            ),
            error: (err, _) => Center(
              child: Text('خطأ في جلب الجدول: $err'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_month_outlined, size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              'لم يتم رفع جدول هذا الصف بعد',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'ستقوم إدارة المدرسة أو المعلم المسؤول برفع وتحديث الجدول قريباً.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractiveDashboard(Map<String, List<String>> tableData, bool isDark, double hPadding) {
    // Collect all available days
    final availableDays = _schoolWeekDays.where((d) => tableData.containsKey(d)).toList();
    if (availableDays.isEmpty) {
      availableDays.addAll(tableData.keys);
    }

    if (_selectedDay == null || !tableData.containsKey(_selectedDay)) {
      _selectedDay = availableDays.first;
    }

    final currentDaySubjects = tableData[_selectedDay] ?? [];

    return Column(
      children: [
        // Days Selector Bar
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: hPadding),
            child: Row(
              children: availableDays.map((day) {
                final isSelected = day == _selectedDay;
                final isCurrentDay = _isToday(day);

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    child: ChoiceChip(
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _selectedDay = day);
                      },
                      selectedColor: AppColors.primary,
                      backgroundColor: isDark ? AppColors.darkCard : Colors.grey.shade100,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : (isCurrentDay
                                  ? AppColors.accent.withValues(alpha: 0.8)
                                  : Colors.transparent),
                          width: isCurrentDay ? 1.5 : 1.0,
                        ),
                      ),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            day,
                            style: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (isCurrentDay) ...[
                            const SizedBox(width: 4),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.accent : AppColors.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // Day Banner Info
        Padding(
          padding: EdgeInsets.fromLTRB(hPadding, 12, hPadding, 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.event_note_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    'حصص يوم $_selectedDay',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (_isToday(_selectedDay!)) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'اليوم الحالي ⭐',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                '${currentDaySubjects.length} حصص',
                style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),

        // List of Periods
        Expanded(
          child: currentDaySubjects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.weekend_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'لا توجد حصص مسجلة ليوم $_selectedDay',
                        style: const TextStyle(fontSize: 15, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : AnimationLimiter(
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 8),
                    itemCount: currentDaySubjects.length,
                    itemBuilder: (context, index) {
                      final subjectName = currentDaySubjects[index];
                      final periodNumber = index + 1;
                      final subjectIcon = _getSubjectIcon(subjectName);
                      final gradient = AppColors.getSubjectGradient(index);

                      return AnimationConfiguration.staggeredList(
                        position: index,
                        duration: const Duration(milliseconds: 350),
                        child: SlideAnimation(
                          verticalOffset: 20.0,
                          child: FadeInAnimation(
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: gradient,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: gradient[0].withValues(alpha: 0.3),
                                        blurRadius: 6,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Icon(subjectIcon, color: Colors.white, size: 24),
                                ),
                                title: Text(
                                  subjectName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                subtitle: Text(
                                  'الحصة رقم $periodNumber',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white60 : Colors.black54,
                                  ),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '#$periodNumber',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildImageView(String imageUrl, bool isDark) {
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
              const Icon(Icons.touch_app_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'اضغط على الجدول لتكبيره والتصفح بملء الشاشة',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen_rounded, color: AppColors.primary),
                tooltip: 'ملء الشاشة',
                onPressed: () => _openFullScreen(context, imageUrl),
              ),
            ],
          ),
        ),
        // Image Viewer
        Expanded(
          child: GestureDetector(
            onTap: () => _openFullScreen(context, imageUrl),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Hero(
                tag: 'schedule_image',
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: _buildScheduleImageWidget(imageUrl),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
