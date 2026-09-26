import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/announcement.dart';
import '../models/comment.dart';

class AnnouncementService {
  final SupabaseClient _supabase;

  AnnouncementService(this._supabase);

  // Fetch announcements with standard REST (works even when Realtime is disabled)
  Future<List<Announcement>> getAnnouncements(String schoolId) async {
    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('school_id', schoolId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      return (response as List).map((e) => Announcement.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // Stream announcements with safe fallback
  Stream<List<Announcement>> watchAnnouncements(String schoolId) async* {
    yield await getAnnouncements(schoolId);

    try {
      final stream = _supabase
          .from('announcements')
          .stream(primaryKey: ['id'])
          .eq('school_id', schoolId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .map((data) => data.map((e) => Announcement.fromJson(e)).toList())
          .handleError((error) {
            debugPrint('[AnnouncementService] Realtime stream notice: $error');
          });

      yield* stream;
    } catch (_) {
      yield await getAnnouncements(schoolId);
    }
  }

  // Add announcement (Teacher)
  Future<void> addAnnouncement(Announcement announcement) async {
    try {
      await _supabase.from('announcements').insert(announcement.toJson());
    } catch (e) {
      throw Exception('فشل في نشر الإعلان: $e');
    }
  }

  // Delete announcement (Soft delete)
  Future<void> deleteAnnouncement(String id) async {
    try {
      await _supabase
          .from('announcements')
          .update({'is_deleted': true})
          .eq('id', id);
    } catch (e) {
      throw Exception('فشل في حذف الإعلان: $e');
    }
  }

  // Fetch comments safely with standard REST
  Future<List<Comment>> getComments(String announcementId) async {
    try {
      final response = await _supabase
          .from('announcement_comments')
          .select()
          .eq('announcement_id', announcementId)
          .order('created_at', ascending: true);

      return (response as List).map((e) => Comment.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // Stream comments with safe fallback
  Stream<List<Comment>> watchComments(String announcementId) async* {
    yield await getComments(announcementId);

    try {
      final stream = _supabase
          .from('announcement_comments')
          .stream(primaryKey: ['id'])
          .eq('announcement_id', announcementId)
          .order('created_at', ascending: true)
          .map((data) => data.map((e) => Comment.fromJson(e)).toList())
          .handleError((error) {
            debugPrint('[AnnouncementService] Realtime comments notice: $error');
          });

      yield* stream;
    } catch (_) {
      yield await getComments(announcementId);
    }
  }

  // Add comment
  Future<void> addComment(Comment comment) async {
    try {
      final data = Map<String, dynamic>.from(comment.toJson());
      if (data['id'] == null || data['id'] == '') {
        data.remove('id');
      }
      await _supabase.from('announcement_comments').insert(data);
    } catch (e) {
      throw Exception('فشل في إضافة التعليق: $e');
    }
  }

  // Delete comment (Teacher only)
  Future<void> deleteComment(String commentId) async {
    try {
      await _supabase.from('announcement_comments').delete().eq('id', commentId);
    } catch (e) {
      throw Exception('فشل في حذف التعليق: $e');
    }
  }
}