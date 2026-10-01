import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_day_helper.dart';
import '../../announcements/providers/announcement_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/views/onboarding_screen.dart';
import '../../homework/models/homework.dart';
import '../../homework/providers/homework_providers.dart';
import 'add_announcement_screen.dart';
import 'add_homework_screen.dart';
import 'manage_comments_screen.dart';
import 'manage_schedule_screen.dart';
import 'manage_subjects/manage_subjects_screen.dart';

// Real stats provider querying Supabase (strictly isolated by schoolId)
final teacherStatsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final schoolId = AppConstants.sanitizeSchoolId(ref.watch(localStorageServiceProvider).getSchoolCode());

  int classesCount = 0;
  int activeHomeworkCount = 0;
  int completedHomeworkCount = 0;
  int announcementsCount = 0;

  try {
    final classesList = await ref.read(homeworkServiceProvider).getClasses(schoolId);
    classesCount = classesList.length;
  } catch (_) {}

  try {
    final hwStats = await ref.read(homeworkServiceProvider).getDashboardHomeworkStats(schoolId);
    activeHomeworkCount = hwStats['active'] ?? 0;
    completedHomeworkCount = hwStats['completed'] ?? 0;
  } catch (_) {}

  try {
    final anns = await ref.read(announcementServiceProvider).getAnnouncements(schoolId);
    announcementsCount = anns.length;
  } catch (_) {}

  return {
    'classes': classesCount,
    'homework': activeHomeworkCount,
    'completed_homework': completedHomeworkCount,
    'announcements': announcementsCount,
  };
});

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من تسجيل الخروج من لوحة التحكم؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authServiceProvider).logout();
              await ref.read(localStorageServiceProvider).clearSession();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(teacherStatsProvider);
    final localStorage = ref.watch(localStorageServiceProvider);
    final activeSchool = ref.watch(activeSchoolProvider).valueOrNull;
    final schoolName = activeSchool?.name ?? localStorage.getSchoolName() ?? '';
    final schoolShortCode = activeSchool?.schoolCode ?? localStorage.getSchoolShortCode() ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('لوحة تحكم الكادر التعليمي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            if (schoolName.isNotEmpty)
              Text(
                schoolShortCode.isNotEmpty ? '$schoolName ($schoolShortCode)' : schoolName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث البيانات',
            onPressed: () {
              ref.invalidate(teacherStatsProvider);
              ref.invalidate(activeSchoolProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            tooltip: 'تسجيل الخروج',
            onPressed: () => _showLogoutDialog(context, ref),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            children: [
              // Header Banner showing Logged-in School
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
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
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                      ),
                      child: const Center(
                        child: Icon(Icons.school_rounded, color: Colors.white, size: 30),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (schoolName.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.account_balance_rounded, color: Colors.white, size: 14),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      schoolShortCode.isNotEmpty
                                          ? '$schoolName • الكود: $schoolShortCode'
                                          : schoolName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          const Text(
                            'أهلاً بك أستاذنا الفاضل 🌟',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'إدارة الواجبات، الإعلانات، وجدول الحصص اليومي',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Statistics Section
              statsAsync.when(
                data: (stats) {
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            context,
                            title: 'الصفوف المسجلة',
                            value: '${stats['classes'] ?? 0}',
                            icon: Icons.meeting_room_rounded,
                            color: const Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatItem(
                            context,
                            title: 'تحاضير نشطة',
                            value: '${stats['homework'] ?? 0}',
                            icon: Icons.pending_actions_rounded,
                            color: const Color(0xFF3B82F6),
                            onTap: () => _showActiveHomeworkSheet(context, ref),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatItem(
                            context,
                            title: 'تحاضير مكتملة',
                            value: '${stats['completed_homework'] ?? 0}',
                            icon: Icons.task_alt_rounded,
                            color: const Color(0xFF10B981),
                            onTap: () => _showCompletedHomeworkSheet(context, ref),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildStatItem(
                            context,
                            title: 'إعلانات منشورة',
                            value: '${stats['announcements'] ?? 0}',
                            icon: Icons.campaign_rounded,
                            color: const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 24),

              // Actions List
              const Text(
                'إجراءات سريعة للإدارة',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              _buildActionTile(
                context,
                icon: Icons.assignment_add,
                title: 'إضافة تحضير مدرسي جديد',
                subtitle: 'إسناد واجبات يومية للطلاب وتحديد موعد التسليم',
                gradient: const [Color(0xFF3B82F6), Color(0xFF2563EB)],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddHomeworkScreen())),
              ),
              const SizedBox(height: 12),

              _buildActionTile(
                context,
                icon: Icons.playlist_remove_rounded,
                title: 'عرض وحذف التحاضير المدرسية',
                subtitle: 'مراجعة جميع الواجبات المرسلة وإمكانية حذف أي واجب أُرسل بالخطأ',
                gradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
                onTap: () => _showActiveHomeworkSheet(context, ref),
              ),
              const SizedBox(height: 12),

              _buildActionTile(
                context,
                icon: Icons.campaign_rounded,
                title: 'نشر وإدارة التبليغات المدرسية',
                subtitle: 'إرسال تنبيهات فورية للطلاب مع إمكانية حذف التبليغات السابقة',
                gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAnnouncementScreen())),
              ),
              const SizedBox(height: 12),

              _buildActionTile(
                context,
                icon: Icons.menu_book_rounded,
                title: 'إدارة المواد والمناهج الدراسية',
                subtitle: 'إضافة أو تعديل أو حذف مواد الصفوف والمقررات الوزارية',
                gradient: const [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageSubjectsScreen())),
              ),
              const SizedBox(height: 12),

              _buildActionTile(
                context,
                icon: Icons.calendar_month_rounded,
                title: 'تعديل جدول الحصص الأسبوعي',
                subtitle: 'رفع وتحديث صورة جدول الدروس لكل صف دراسي',
                gradient: const [Color(0xFF10B981), Color(0xFF059669)],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageScheduleScreen())),
              ),
              const SizedBox(height: 12),

              _buildActionTile(
                context,
                icon: Icons.forum_rounded,
                title: 'إدارة التبليغات وتعليقات الطلاب',
                subtitle: 'الرد على استفسارات الطلبة، أو حذف التعليقات والتبليغات',
                gradient: const [Color(0xFFEC4899), Color(0xFFDB2777)],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCommentsScreen())),
              ),
              const SizedBox(height: 12),

              _buildActionTile(
                context,
                icon: Icons.restart_alt_rounded,
                title: 'بدء عام دراسي جديد (مسح أرشيف السنة السابقة)',
                subtitle: 'مسح جميع الواجبات والأرشيف والتبليغات القديمة مع الاحتفاظ بالصفوف والمواد',
                gradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
                onTap: () => _showResetAcademicYearDialog(context, ref),
              ),
              const SizedBox(height: 16),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'منظومة مدرستي • الإصدار ${AppConstants.appVersion}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showResetAcademicYearDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'بدء عام دراسي جديد',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من بدء عام دراسي جديد؟\n\nسيؤدي هذا الإجراء إلى مسح جميع التحاضير والواجبات السابقة وأرشيف العام الماضي والتبليغات القديمة لهذه المدرسة، مع الاحتفاظ بجميع الصفوف والمواد الدراسية كما هي.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final schoolId = AppConstants.sanitizeSchoolId(
                ref.read(localStorageServiceProvider).getSchoolCode(),
              );
              await ref.read(homeworkServiceProvider).resetSchoolAcademicYear(schoolId);
              ref.invalidate(teacherStatsProvider);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم مسح أرشيف العام السابق وبدء عام دراسي جديد بنجاح! 🎉'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: const Text('نعم، مسح الأرشيف وبدء عام جديد'),
          ),
        ],
      ),
    );
  }

  Future<void> _showActiveHomeworkSheet(BuildContext context, WidgetRef ref) async {
    final schoolId = AppConstants.sanitizeSchoolId(ref.read(localStorageServiceProvider).getSchoolCode());
    final activeList = await ref.read(homeworkServiceProvider).getAllActiveHomework(schoolId);
    if (!context.mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              maxChildSize: 0.90,
              minChildSize: 0.35,
              builder: (_, controller) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.pending_actions_rounded, color: Color(0xFF3B82F6)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'التحاضير النشطة (المرسلة للطلاب)',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'يمكنك الضغط على سلة المحذوفات لحذف أي واجب تم إرساله بالخطأ فوراً.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                      const Divider(),
                      Expanded(
                        child: activeList.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا توجد تحاضير نشطة حالياً',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                controller: controller,
                                itemCount: activeList.length,
                                itemBuilder: (context, index) {
                                  final hw = activeList[index];
                                  return Card(
                                    color: isDark ? AppColors.darkCard : Colors.grey.shade50,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Icon(
                                          Icons.assignment_rounded,
                                          color: Color(0xFF3B82F6),
                                          size: 24,
                                        ),
                                      ),
                                      title: Text(
                                        hw.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const SizedBox(height: 2),
                                          Text(
                                            ArabicDayHelper.formatDescriptionDatesToDayNames(hw.description),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            hw.deadline != null
                                                ? '📅 موعد التسليم: ${ArabicDayHelper.formatFullDayDateTime(hw.deadline!)}'
                                                : 'نشر في: ${ArabicDayHelper.formatDayAndDate(hw.createdAt)}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF3B82F6),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                        tooltip: 'حذف هذا الواجب',
                                        onPressed: () {
                                          _confirmDeleteHomework(context, ref, hw, () {
                                            setSheetState(() {
                                              activeList.removeWhere((item) => item.id == hw.id);
                                            });
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showCompletedHomeworkSheet(BuildContext context, WidgetRef ref) async {
    final schoolId = AppConstants.sanitizeSchoolId(ref.read(localStorageServiceProvider).getSchoolCode());
    final completedList = await ref.read(homeworkServiceProvider).getAllCompletedHomework(schoolId);
    if (!context.mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.55,
              maxChildSize: 0.85,
              minChildSize: 0.35,
              builder: (_, controller) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.task_alt_rounded, color: AppColors.success),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'التحاضير المنتهية والمكتملة',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: completedList.isEmpty
                            ? const Center(
                                child: Text(
                                  'لا توجد تحاضير منتهية الوقت حتى الآن',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                controller: controller,
                                itemCount: completedList.length,
                                itemBuilder: (context, index) {
                                  final hw = completedList[index];
                                  return Card(
                                    color: isDark ? AppColors.darkCard : Colors.grey.shade50,
                                    margin: const EdgeInsets.only(bottom: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      side: BorderSide(
                                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                      ),
                                    ),
                                    child: ListTile(
                                      leading: const Icon(
                                        Icons.timer_off_rounded,
                                        color: AppColors.success,
                                      ),
                                      title: Text(
                                        hw.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ArabicDayHelper.formatDescriptionDatesToDayNames(hw.description),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            hw.deadline != null
                                                ? ArabicDayHelper.formatFullDayDateTime(hw.deadline!)
                                                : ArabicDayHelper.formatDayAndDate(hw.createdAt),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.success.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'انتهى ⏰',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.success,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                            tooltip: 'حذف',
                                            onPressed: () {
                                              _confirmDeleteHomework(context, ref, hw, () {
                                                setSheetState(() {
                                                  completedList.removeWhere((item) => item.id == hw.id);
                                                });
                                              });
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmDeleteHomework(
    BuildContext context,
    WidgetRef ref,
    Homework hw,
    VoidCallback onDeleted,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.red, size: 26),
            SizedBox(width: 8),
            Text(
              'حذف التحضير المدرسي',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          'هل أنت متأكد من حذف تحضير "${hw.title}"؟\n\nسيتم إلغاؤه واختفاؤه فوراً من عند جميع الطلاب.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await ref
                    .read(homeworkServiceProvider)
                    .deleteHomework(hw.id, subjectId: hw.subjectId);
                ref.invalidate(teacherStatsProvider);
                ref.invalidate(currentHomeworkProvider(hw.subjectId));
                ref.invalidate(homeworkArchiveProvider(hw.subjectId));
                onDeleted();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم حذف التحضير بنجاح واختفائه من هواتف الطلاب! 🗑️'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('فشل في حذف التحضير: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('نعم، حذف الواجب'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, color: Colors.grey, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: gradient),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}