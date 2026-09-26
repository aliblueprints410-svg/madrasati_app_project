import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/providers/auth_providers.dart';
import '../../auth/views/onboarding_screen.dart';
import 'add_announcement_screen.dart';
import 'add_homework_screen.dart';
import 'manage_comments_screen.dart';
import 'manage_schedule_screen.dart';
import 'manage_subjects/manage_subjects_screen.dart';

// Real stats provider querying Supabase
final teacherStatsProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final schoolId = AppConstants.sanitizeSchoolId(ref.watch(localStorageServiceProvider).getSchoolCode());

  int classesCount = 0;
  int activeHomeworkCount = 0;
  int announcementsCount = 0;

  try {
    var classesQuery = supabase.from('classes').select('id');
    if (schoolId.isNotEmpty) {
      classesQuery = classesQuery.eq('school_id', schoolId);
    }
    final classesRes = await classesQuery;
    classesCount = (classesRes as List).length;
  } catch (_) {}

  try {
    final hwRes = await supabase
        .from('homework')
        .select('id')
        .eq('is_current', true)
        .eq('is_deleted', false);
    activeHomeworkCount = (hwRes as List).length;
  } catch (_) {}

  try {
    var annQuery = supabase.from('announcements').select('id').eq('is_deleted', false);
    if (schoolId.isNotEmpty) {
      annQuery = annQuery.eq('school_id', schoolId);
    }
    final annRes = await annQuery;
    announcementsCount = (annRes as List).length;
  } catch (_) {}

  return {
    'classes': classesCount,
    'homework': activeHomeworkCount,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الكادر التعليمي', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث البيانات',
            onPressed: () => ref.invalidate(teacherStatsProvider),
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
              // Header Banner
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
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'أهلاً بك أستاذنا الفاضل 🌟',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
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
                  return Row(
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem(
                          context,
                          title: 'تحاضير نشطة',
                          value: '${stats['homework'] ?? 0}',
                          icon: Icons.assignment_turned_in_rounded,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                icon: Icons.campaign_rounded,
                title: 'نشر إعلان مدرسي للجميع',
                subtitle: 'إرسال تنبيهات وتوجيهات فورية لجميع الطلاب وأولياء الأمور',
                gradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddAnnouncementScreen())),
              ),
              const SizedBox(height: 12),

              _buildActionTile(
                context,
                icon: Icons.menu_book_rounded,
                title: 'إدارة المواد والمناهج الدراسية',
                subtitle: 'إضافة أو تعديل مواد الصفوف والمقررات الوزارية',
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
                title: 'إدارة تعليقات واستفسارات الطلاب',
                subtitle: 'مراجعة تعليقات واستفسارات الطلبة على الإعلانات',
                gradient: const [Color(0xFFEC4899), Color(0xFFDB2777)],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManageCommentsScreen())),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, {required String title, required String value, required IconData icon, required Color color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
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