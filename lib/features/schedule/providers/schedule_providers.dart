import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';

final classScheduleImageProvider = FutureProvider.family<String?, String>((ref, classId) async {
  final supabase = ref.watch(supabaseClientProvider);

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
    return null;
  } catch (_) {
    // If schedule_image_url column doesn't exist yet or query fails, return null cleanly
    return null;
  }
});
