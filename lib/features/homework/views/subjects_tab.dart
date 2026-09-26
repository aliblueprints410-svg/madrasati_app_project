import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../models/subject.dart';
import '../providers/homework_providers.dart';
import 'grade_selection_screen.dart';
import 'subject_details_screen.dart';

class SubjectsTab extends ConsumerWidget {
  const SubjectsTab({super.key});

  IconData _getSubjectIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('رياضيات') || lower.contains('math')) {
      return Icons.calculate_rounded;
    } else if (lower.contains('علوم') || lower.contains('science')) {
      return Icons.science_rounded;
    } else if (lower.contains('عربي') || lower.contains('قراءة') || lower.contains('لغة عربية') || lower.contains('اللغة')) {
      return Icons.auto_stories_rounded;
    } else if (lower.contains('انكليزي') || lower.contains('إنكليزي') || lower.contains('english')) {
      return Icons.translate_rounded;
    } else if (lower.contains('اسلامية') || lower.contains('إسلامية') || lower.contains('دين') || lower.contains('قرآن')) {
      return Icons.menu_book_rounded;
    } else if (lower.contains('أخلاق') || lower.contains('اخلاق')) {
      return Icons.favorite_rounded;
    } else if (lower.contains('اجتماعيات') || lower.contains('تاريخ') || lower.contains('جغرافيا')) {
      return Icons.public_rounded;
    } else if (lower.contains('فنية') || lower.contains('رسم')) {
      return Icons.palette_rounded;
    } else if (lower.contains('رياضة') || lower.contains('بدنية')) {
      return Icons.sports_soccer_rounded;
    } else if (lower.contains('حاسوب') || lower.contains('كمبيوتر') || lower.contains('تقنية')) {
      return Icons.computer_rounded;
    }
    return Icons.school_rounded;
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'صباح الخير والنشاط ✨';
    } else if (hour >= 12 && hour < 17) {
      return 'مساء الخير والاجتهاد 🌟';
    } else {
      return 'مساء الهدوء والتحصيل 🌙';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localStorage = ref.watch(localStorageServiceProvider);
    final gradeId = localStorage.getSelectedGrade();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hPadding = Responsive.getHorizontalPadding(context);
    final gridCount = Responsive.getGridCrossAxisCount(context);

    if (gradeId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('يرجى اختيار الصف الدراسي أولاً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GradeSelectionScreen()),
                  );
                },
                child: const Text('اختيار الصف الدراسي'),
              ),
            ],
          ),
        ),
      );
    }

    final subjectsAsync = ref.watch(subjectsProvider(gradeId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('المواد الدراسية', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GradeSelectionScreen()),
              );
            },
            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
            label: const Text('تغيير الصف', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 14.0),
            children: [
              // Welcome Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getTimeGreeting(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'اختر المادة لمشاهدة الواجبات والتحاضير المدرسية اليومية',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 30),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.category_rounded, size: 18, color: isDark ? AppColors.primary : AppColors.primary),
                    const SizedBox(width: 8),
                    const Text(
                      'المناهج والمقررات المقررة',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Subjects Grid
              subjectsAsync.when(
                data: (subjects) {
                  if (subjects.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          children: [
                            Icon(Icons.auto_stories_outlined, size: 54, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'لا توجد مواد مسجلة لهذا الصف بعد',
                              style: TextStyle(fontSize: 15, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return AnimationLimiter(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: gridCount,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: subjects.length,
                      itemBuilder: (context, index) {
                        final subject = subjects[index];
                        final gradient = AppColors.getSubjectGradient(index);

                        return AnimationConfiguration.staggeredGrid(
                          position: index,
                          duration: const Duration(milliseconds: 350),
                          columnCount: gridCount,
                          child: ScaleAnimation(
                            child: FadeInAnimation(
                              child: _buildSubjectCard(context, subject, gradient, isDark),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text('حدث خطأ أثناء تحميل المواد: $err'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(BuildContext context, Subject subject, List<Color> gradient, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SubjectDetailsScreen(subject: subject),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: gradient[0].withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _getSubjectIcon(subject.name),
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subject.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
