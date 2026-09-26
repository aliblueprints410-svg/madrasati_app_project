import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../services/announcement_service.dart';
import '../models/announcement.dart';
import '../models/comment.dart';

// Service Provider
final announcementServiceProvider = Provider<AnnouncementService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AnnouncementService(supabase);
});

// Stream Providers
final announcementsProvider = StreamProvider.family<List<Announcement>, String>((ref, schoolId) {
  final service = ref.watch(announcementServiceProvider);
  return service.watchAnnouncements(schoolId);
});

final commentsProvider = StreamProvider.family<List<Comment>, String>((ref, announcementId) {
  final service = ref.watch(announcementServiceProvider);
  return service.watchComments(announcementId);
});
