import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/providers/core_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/shimmer_loading.dart';
import '../providers/announcement_providers.dart';
import 'announcement_details_screen.dart';

class AnnouncementsTab extends ConsumerStatefulWidget {
  const AnnouncementsTab({super.key});

  @override
  ConsumerState<AnnouncementsTab> createState() => _AnnouncementsTabState();
}

class _AnnouncementsTabState extends ConsumerState<AnnouncementsTab> {
  @override
  void initState() {
    super.initState();
    timeago.setLocaleMessages('ar', timeago.ArMessages());
  }

  @override
  Widget build(BuildContext context) {
    final localStorage = ref.watch(localStorageServiceProvider);
    final schoolId = localStorage.getSchoolCode();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (schoolId == null) {
      return const Scaffold(body: Center(child: Text('خطأ: كود المدرسة مفقود')));
    }

    final announcementsAsync = ref.watch(announcementsProvider(schoolId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة التبليغات المدرسية', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(announcementsProvider(schoolId));
            },
        child: announcementsAsync.when(
          data: (announcements) {
            if (announcements.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.campaign_outlined, size: 64, color: AppColors.primary.withOpacity(0.6)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'لا توجد إعلانات أو تبليغات حالياً',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'سيتم إشعارك هنا عند نشر أي قرار أو تبليغ جديد من المدرسة',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return AnimationLimiter(
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  final ann = announcements[index];
                  final isPriority = ann.priority;

                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 350),
                    child: SlideAnimation(
                      verticalOffset: 30.0,
                      child: FadeInAnimation(
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isPriority
                                  ? const Color(0xFFF87171)
                                  : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                              width: isPriority ? 1.8 : 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isPriority
                                    ? Colors.red.withOpacity(0.12)
                                    : Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
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
                                  PageRouteBuilder(
                                    transitionDuration: const Duration(milliseconds: 350),
                                    pageBuilder: (_, __, ___) => AnnouncementDetailsScreen(announcement: ann),
                                    transitionsBuilder: (_, animation, __, child) {
                                      return FadeTransition(opacity: animation, child: child);
                                    },
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header: Priority Badge or Normal Category
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        if (isPriority)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEE2E2),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFDC2626)),
                                                SizedBox(width: 4),
                                                Text(
                                                  'هام وعاجل',
                                                  style: TextStyle(
                                                    color: Color(0xFFDC2626),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.campaign_rounded, size: 14, color: AppColors.primary),
                                                SizedBox(width: 4),
                                                Text(
                                                  'إعلان مدرسي',
                                                  style: TextStyle(
                                                    color: AppColors.primary,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        // Time
                                        Row(
                                          children: [
                                            Icon(Icons.access_time_rounded, size: 13, color: Colors.grey.shade400),
                                            const SizedBox(width: 4),
                                            Text(
                                              timeago.format(ann.createdAt, locale: 'ar'),
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),

                                    // Title
                                    Text(
                                      ann.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isPriority
                                            ? const Color(0xFFDC2626)
                                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Content snippet
                                    Text(
                                      ann.content,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.5,
                                        color: isDark ? AppColors.darkTextSecondary : const Color(0xFF475569),
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    // Detailed publish info
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.event_note_rounded, size: 14, color: isPriority ? const Color(0xFFDC2626) : AppColors.primary),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'تم النشر: ${DateFormat('yyyy-MM-dd • hh:mm a').format(ann.createdAt).replaceAll('AM', 'صباحاً').replaceAll('PM', 'مساءً')}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Bottom row with Comments prompt
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Text(
                                          'عرض التفاصيل والتعليقات',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isPriority ? const Color(0xFFDC2626) : AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_back_ios_new_rounded,
                                          size: 11,
                                          color: isPriority ? const Color(0xFFDC2626) : AppColors.primary,
                                        ),
                                      ],
                                    ),
                                  ],
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
            );
          },
          loading: () => ListView.builder(
            padding: const EdgeInsets.all(18),
            itemCount: 4,
            itemBuilder: (context, index) => ShimmerLoading(
              child: Container(
                height: 130,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          error: (err, stack) => Center(child: Text('خطأ في جلب الإعلانات: $err')),
        ),
      ),
    ),
  ),
);
}
}
