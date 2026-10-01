import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/core_providers.dart';

const String kSysSchedulePrefix = '__SYS_SCHEDULE_V2__:';
const String kLegacySysSchedulePrefix = '__SYS_SCHEDULE__:';
const String kLocalScheduleKeyPrefix = 'schedule_image_';

final classScheduleImageProvider = FutureProvider.family<String?, String>((ref, classId) async {
  final supabase = ref.watch(supabaseClientProvider);

  // 1. Check V2 cloud schedule record in announcements
  try {
    final sysTitle = '$kSysSchedulePrefix$classId';
    final sysRows = await supabase
        .from('announcements')
        .select('content')
        .eq('title', sysTitle)
        .order('created_at', ascending: false)
        .limit(1);

    if ((sysRows as List).isNotEmpty) {
      final content = sysRows.first['content'] as String?;
      if (content != null && content.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('$kLocalScheduleKeyPrefix$classId', content);
        } catch (_) {}
        return content;
      }
    }
  } catch (_) {}

  // 2. Check local SharedPreferences cache (updated immediately on teacher upload)
  try {
    final prefs = await SharedPreferences.getInstance();
    final localImg = prefs.getString('$kLocalScheduleKeyPrefix$classId');
    if (localImg != null && localImg.isNotEmpty) {
      return localImg;
    }
  } catch (_) {}

  // 3. Check legacy cloud schedule record in announcements
  try {
    final legacyTitle = '$kLegacySysSchedulePrefix$classId';
    final legacyRows = await supabase
        .from('announcements')
        .select('content')
        .eq('title', legacyTitle)
        .order('created_at', ascending: false)
        .limit(1);

    if ((legacyRows as List).isNotEmpty) {
      final content = legacyRows.first['content'] as String?;
      if (content != null && content.isNotEmpty) {
        return content;
      }
    }
  } catch (_) {}

  // 2. Check classes.schedule_image_url if column exists
  try {
    final response = await supabase
        .from('classes')
        .select('schedule_image_url')
        .eq('id', classId)
        .maybeSingle();

    if (response != null && response['schedule_image_url'] != null) {
      final url = response['schedule_image_url'] as String;
      if (url.isNotEmpty) return url;
    }
  } catch (_) {}

  // 3. Check schedules table if schedule_data contains image_url
  try {
    final schedRes = await supabase
        .from('schedules')
        .select('schedule_data')
        .eq('class_id', classId)
        .maybeSingle();

    if (schedRes != null && schedRes['schedule_data'] is Map) {
      final map = schedRes['schedule_data'] as Map;
      final url = map['image_url']?.toString();
      if (url != null && url.isNotEmpty) return url;
    }
  } catch (_) {}

  // 4. Fallback to local SharedPreferences cache
  try {
    final prefs = await SharedPreferences.getInstance();
    final localImg = prefs.getString('$kLocalScheduleKeyPrefix$classId');
    if (localImg != null && localImg.isNotEmpty) {
      return localImg;
    }
  } catch (_) {}

  return null;
});
