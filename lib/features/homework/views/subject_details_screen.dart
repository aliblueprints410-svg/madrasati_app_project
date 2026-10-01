import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_day_helper.dart';
import '../../../core/utils/subject_visual_helper.dart';
import '../../../core/widgets/confetti_celebration.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../models/subject.dart';
import '../models/homework.dart';
import '../providers/homework_providers.dart';
import '../widgets/homework_card.dart';

class SubjectDetailsScreen extends ConsumerStatefulWidget {
  final Subject subject;

  const SubjectDetailsScreen({super.key, required this.subject});

  @override
  ConsumerState<SubjectDetailsScreen> createState() => _SubjectDetailsScreenState();
}

class _SubjectDetailsScreenState extends ConsumerState<SubjectDetailsScreen> {
  int _selectedSection = 0; // 0: Current, 1: Archive

  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markSubjectAsViewed();
    });
  }

  Future<void> _markSubjectAsViewed() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setInt('subject_last_viewed_${widget.subject.id}', DateTime.now().millisecondsSinceEpoch);
      ref.invalidate(subjectHasUnreadHomeworkProvider(widget.subject.id));
    } catch (_) {}
  }

  Future<void> _markAsCompleted(Homework hw) async {
    // 1. Move homework to archive (student local completion)
    await ref.read(homeworkServiceProvider).archiveHomework(
      hw.id,
      subjectId: widget.subject.id,
    );
    ref.invalidate(currentHomeworkProvider(widget.subject.id));
    ref.invalidate(homeworkArchiveProvider(widget.subject.id));
    ref.invalidate(studentCompletedHomeworkIdsProvider);

    if (!mounted) return;

    // 2. Trigger the global confetti particle explosion!
    ConfettiCelebrationOverlay.trigger(context);

    // 3. Show celebration bottom sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  gradient: AppColors.successGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'عاشت إيدك! بطل ومتميز 👏🎉',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.success,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'تم إنجاز واجب "${hw.title}" بنجاح ونقله إلى خانة مكتمل.',
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.5, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        if (mounted) {
                          setState(() => _selectedSection = 1);
                        }
                      },
                      icon: const Icon(Icons.task_alt_rounded, size: 18),
                      label: const Text('عرض المكتمل'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('متابعة الدراسة 📚'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentHomeworkAsync = ref.watch(currentHomeworkProvider(widget.subject.id));
    final archiveHomeworkAsync = ref.watch(homeworkArchiveProvider(widget.subject.id));
    final completedIds = ref.watch(studentCompletedHomeworkIdsProvider).valueOrNull ?? <String>{};
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.subject.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentHomeworkProvider(widget.subject.id));
              ref.invalidate(homeworkArchiveProvider(widget.subject.id));
              ref.invalidate(studentCompletedHomeworkIdsProvider);
            },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // Subject Banner Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: SubjectVisualHelper.getSubjectGradient(widget.subject.name),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: SubjectVisualHelper.getSubjectGradient(widget.subject.name)[0].withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
                    ),
                    child: Icon(
                      SubjectVisualHelper.getSubjectIcon(widget.subject.name),
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.subject.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'تابع واجباتك وتحضيرك المدرسي اليومي',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Segmented Filter (Current Homework vs Archive)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedSection = 0),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedSection == 0
                              ? (isDark ? AppColors.primary : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _selectedSection == 0
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_turned_in_rounded,
                              size: 18,
                              color: _selectedSection == 0
                                  ? (_selectedSection == 0 && isDark ? Colors.white : AppColors.primary)
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'تحضير اليوم',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedSection == 0
                                    ? (_selectedSection == 0 && isDark ? Colors.white : AppColors.primary)
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedSection = 1),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedSection == 1
                              ? (isDark ? AppColors.primary : Colors.white)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _selectedSection == 1
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.task_alt_rounded,
                              size: 18,
                              color: _selectedSection == 1
                                  ? (_selectedSection == 1 && isDark ? Colors.white : AppColors.primary)
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'مكتمل',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: _selectedSection == 1
                                    ? (_selectedSection == 1 && isDark ? Colors.white : AppColors.primary)
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Content according to selected section
            if (_selectedSection == 0) ...[
              currentHomeworkAsync.when(
                data: (homeworks) {
                  if (homeworks.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? AppColors.darkBorder : const Color(0xFFBBF7D0),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.sentiment_very_satisfied_rounded,
                              size: 56,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'لا يوجد تحضير لليوم! 🎉',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF15803D),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'يمكنك استغلال الوقت لمراجعة الدروس السابقة أو أخذ قسط من الراحة.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white70 : const Color(0xFF166534),
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: homeworks.map((hw) {
                      return HomeworkCard(
                        homework: hw,
                        onComplete: () => _markAsCompleted(hw),
                      );
                    }).toList(),
                  );
                },
                loading: () => ShimmerLoading(
                  child: Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                error: (err, stack) => Center(child: Text('خطأ: $err')),
              ),
            ] else ...[
              archiveHomeworkAsync.when(
                data: (homeworks) {
                  if (homeworks.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(36),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.task_alt_rounded, size: 50, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'لا توجد تحاضير مكتملة لهذه المادة بعد',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: homeworks.length,
                    itemBuilder: (context, index) {
                      final hw = homeworks[index];
                      final isCompletedByStudent = completedIds.contains(hw.id);
                      final statusColor = isCompletedByStudent ? AppColors.success : Colors.redAccent;
                      final statusText = isCompletedByStudent ? 'تم إنجاز الواجب ✅' : 'انتهى وقت الواجب ⏰';
                      final statusIcon = isCompletedByStudent ? Icons.check_circle_rounded : Icons.timer_off_rounded;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkCard : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            width: 1.2,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(statusIcon, size: 16, color: statusColor),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      hw.title,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: statusColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    hw.deadline != null
                                        ? ArabicDayHelper.formatFullDayDateTime(hw.deadline!)
                                        : ArabicDayHelper.formatDayAndDate(hw.createdAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                ArabicDayHelper.formatDescriptionDatesToDayNames(hw.description),
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('خطأ: $err')),
              ),
            ],
          ],
        ),
      ),
    ),
  ),
);
}
}
