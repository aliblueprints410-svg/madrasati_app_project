import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../models/announcement.dart';
import '../models/comment.dart';

class AnnouncementService {
  final SupabaseClient _supabase;

  AnnouncementService(this._supabase);

  static const String _sysPrefix = '__SYS_';
  static const String _sysCommentsPrefix = '__SYS_COMMENTS__:';
  static const String _sysDeletedAnnPrefix = '__SYS_DELETED_ANN__:';
  static const String _localCommentsKeyPrefix = 'local_comments_';
  static const String _deletedCommentsKey = 'deleted_comment_ids';
  static const String _deletedAnnouncementsKey = 'deleted_announcement_ids';

  // Obtain an authenticated access token without altering the current student/teacher session
  Future<String?> _getBackgroundAccessToken() async {
    final activeToken = _supabase.auth.currentSession?.accessToken;
    if (activeToken != null && activeToken.isNotEmpty) {
      return activeToken;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('teacher_email');
      final password = prefs.getString('teacher_password');
      final supabaseUrl = dotenv.env[AppConstants.supabaseUrlEnvKey] ?? '';
      final anonKey = dotenv.env[AppConstants.supabaseAnonKeyEnvKey] ?? '';

      if (email != null &&
          email.isNotEmpty &&
          password != null &&
          password.isNotEmpty &&
          supabaseUrl.isNotEmpty &&
          anonKey.isNotEmpty) {
        final response = await http.post(
          Uri.parse('$supabaseUrl/auth/v1/token?grant_type=password'),
          headers: {
            'apikey': anonKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        );
        if (response.statusCode == 200) {
          final body = jsonDecode(response.body);
          return body['access_token'] as String?;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<Set<String>> getDeletedAnnouncementIds(String schoolId) async {
    final Set<String> deletedIds = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      deletedIds.addAll(prefs.getStringList(_deletedAnnouncementsKey) ?? []);
    } catch (_) {}

    try {
      final cleanSchoolId = AppConstants.sanitizeSchoolId(schoolId);
      final sysTitle = '$_sysDeletedAnnPrefix$cleanSchoolId';
      final sysRows = await _supabase
          .from('announcements')
          .select('content')
          .eq('title', sysTitle)
          .order('created_at', ascending: false)
          .limit(15);

      for (final row in (sysRows as List)) {
        final raw = row['content'] as String?;
        if (raw != null && raw.isNotEmpty) {
          final list = (jsonDecode(raw) as List).map((e) => e.toString());
          deletedIds.addAll(list);
        }
      }
      if (deletedIds.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_deletedAnnouncementsKey, deletedIds.toList());
      }
    } catch (_) {}

    return deletedIds;
  }

  // Fetch announcements with standard REST (works even when Realtime is disabled)
  Future<List<Announcement>> getAnnouncements(String schoolId) async {
    try {
      final cleanSchoolId = AppConstants.sanitizeSchoolId(schoolId);
      final deletedIds = await getDeletedAnnouncementIds(cleanSchoolId);

      final response = await _supabase
          .from('announcements')
          .select()
          .eq('school_id', cleanSchoolId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);

      final rows = response as List;
      DateTime? resetTs;
      final resetTitle = '__SYS_RESET_YEAR__:$cleanSchoolId';
      for (final r in rows) {
        if (r['title'] == resetTitle) {
          final parsed = DateTime.tryParse((r['content'] ?? '').toString());
          if (parsed != null && (resetTs == null || parsed.isAfter(resetTs))) {
            resetTs = parsed.toUtc();
          }
        }
      }

      return rows
          .map((e) => Announcement.fromJson(e))
          .where((a) =>
              !a.title.startsWith(_sysPrefix) &&
              !deletedIds.contains(a.id) &&
              (resetTs == null || !a.createdAt.toUtc().isBefore(resetTs)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // Stream announcements with safe fallback
  Stream<List<Announcement>> watchAnnouncements(String schoolId) async* {
    final cleanSchoolId = AppConstants.sanitizeSchoolId(schoolId);
    yield await getAnnouncements(cleanSchoolId);

    try {
      final stream = _supabase
          .from('announcements')
          .stream(primaryKey: ['id'])
          .eq('school_id', cleanSchoolId)
          .order('created_at', ascending: false)
          .asyncMap((_) => getAnnouncements(cleanSchoolId))
          .handleError((error) {
            debugPrint('[AnnouncementService] Realtime stream notice: $error');
          });

      yield* stream;
    } catch (_) {
      yield await getAnnouncements(cleanSchoolId);
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

  // Delete announcement (Works even when UPDATE/DELETE RLS is restricted on announcements)
  Future<void> deleteAnnouncement(String id, {String? schoolId}) async {
    String cleanSchoolId = AppConstants.defaultSchoolId;
    Set<String> deletedIds = {};

    try {
      final prefs = await SharedPreferences.getInstance();
      cleanSchoolId = AppConstants.sanitizeSchoolId(
        schoolId ?? prefs.getString(AppConstants.keySchoolCode),
      );
      deletedIds = await getDeletedAnnouncementIds(cleanSchoolId);
      deletedIds.add(id);
      await prefs.setStringList(_deletedAnnouncementsKey, deletedIds.toList());
    } catch (_) {
      deletedIds.add(id);
    }

    // 1. Try standard soft delete
    try {
      await _supabase
          .from('announcements')
          .update({'is_deleted': true})
          .eq('id', id);
    } catch (_) {}

    // 2. Insert append-only cloud deletion snapshot so all students & teachers sync immediately
    try {
      final sysTitle = '$_sysDeletedAnnPrefix$cleanSchoolId';
      await _supabase.from('announcements').insert({
        'id': const Uuid().v4(),
        'school_id': cleanSchoolId,
        'title': sysTitle,
        'content': jsonEncode(deletedIds.toList()),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'priority': false,
        'is_deleted': false,
      });
    } catch (e) {
      debugPrint('[AnnouncementService] Cloud delete sync notice: $e');
    }
  }

  // Fetch comments safely with standard REST + Cloud/Local fallback
  Future<List<Comment>> getComments(String announcementId) async {
    final Map<String, Comment> merged = {};
    Set<String> deletedIds = {};

    try {
      final prefs = await SharedPreferences.getInstance();
      deletedIds = (prefs.getStringList(_deletedCommentsKey) ?? []).toSet();

      // 1. Load local comments
      final localJsonList = prefs.getStringList('$_localCommentsKeyPrefix$announcementId') ?? [];
      for (final item in localJsonList) {
        try {
          final c = Comment.fromJson(jsonDecode(item) as Map<String, dynamic>);
          if (!deletedIds.contains(c.id)) {
            merged[c.id] = c;
          }
        } catch (_) {}
      }
    } catch (_) {}

    // 2. Load from announcement_comments table
    try {
      final response = await _supabase
          .from('announcement_comments')
          .select()
          .eq('announcement_id', announcementId)
          .order('created_at', ascending: true);

      for (final e in (response as List)) {
        final c = Comment.fromJson(e as Map<String, dynamic>);
        if (!deletedIds.contains(c.id)) {
          merged[c.id] = c;
        }
      }
    } catch (_) {}

    // 3. Load from cloud fallback rows in announcements
    try {
      final sysTitle = '$_sysCommentsPrefix$announcementId';
      final sysRows = await _supabase
          .from('announcements')
          .select('content')
          .eq('title', sysTitle)
          .order('created_at', ascending: false)
          .limit(20);

      for (final row in (sysRows as List).reversed) {
        final rawContent = row['content'] as String?;
        if (rawContent != null && rawContent.isNotEmpty) {
          final decoded = jsonDecode(rawContent) as List;
          for (final item in decoded) {
            final c = Comment.fromJson(item as Map<String, dynamic>);
            if (!deletedIds.contains(c.id)) {
              merged[c.id] = c;
            }
          }
        }
      }
    } catch (_) {}

    final result = merged.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return result;
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
          .asyncMap((_) => getComments(announcementId))
          .handleError((error) {
            debugPrint('[AnnouncementService] Realtime comments notice: $error');
          });

      yield* stream;
    } catch (_) {
      yield await getComments(announcementId);
    }
  }

  // Add comment or teacher reply (Works in Student Mode & Teacher Mode)
  Future<void> addComment(Comment comment) async {
    final commentId = (comment.id.isEmpty) ? const Uuid().v4() : comment.id;
    final normalizedComment = Comment(
      id: commentId,
      announcementId: comment.announcementId,
      senderName: comment.senderName,
      content: comment.content,
      createdAt: comment.createdAt,
    );

    // 1. Always persist locally first so UI updates instantaneously
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_localCommentsKeyPrefix${comment.announcementId}';
      final existing = prefs.getStringList(key) ?? [];
      existing.add(jsonEncode(normalizedComment.toJson()));
      await prefs.setStringList(key, existing);
    } catch (_) {}

    // 2. Try direct insert into announcement_comments
    final data = Map<String, dynamic>.from(normalizedComment.toJson());
    try {
      await _supabase.from('announcement_comments').insert(data);
    } catch (e) {
      debugPrint('[AnnouncementService] Direct comment insert fallback: $e');
    }

    // 3. Always sync comments snapshot to announcements table using INSERT (works when authenticated or with background token)
    try {
      final token = await _getBackgroundAccessToken();
      final supabaseUrl = dotenv.env[AppConstants.supabaseUrlEnvKey] ?? '';
      final anonKey = dotenv.env[AppConstants.supabaseAnonKeyEnvKey] ?? '';

      if (token != null && supabaseUrl.isNotEmpty && anonKey.isNotEmpty) {
        await _syncCommentsToCloudAnnouncement(
          announcementId: comment.announcementId,
          token: token,
          supabaseUrl: supabaseUrl,
          anonKey: anonKey,
        );
      }
    } catch (e) {
      debugPrint('[AnnouncementService] Background comment sync notice: $e');
    }
  }

  Future<void> _syncCommentsToCloudAnnouncement({
    required String announcementId,
    required String token,
    required String supabaseUrl,
    required String anonKey,
  }) async {
    final allComments = await getComments(announcementId);
    final sysTitle = '$_sysCommentsPrefix$announcementId';
    final contentJson = jsonEncode(allComments.map((c) => c.toJson()).toList());

    final prefs = await SharedPreferences.getInstance();
    final schoolId = AppConstants.sanitizeSchoolId(prefs.getString(AppConstants.keySchoolCode));

    // Always INSERT a new row (since Supabase RLS allows INSERT on announcements, not UPDATE)
    await http.post(
      Uri.parse('$supabaseUrl/rest/v1/announcements'),
      headers: {
        'apikey': anonKey,
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'id': const Uuid().v4(),
        'school_id': schoolId,
        'title': sysTitle,
        'content': contentJson,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'priority': false,
        'is_deleted': false,
      }),
    );
  }

  // Delete comment (Teacher only)
  Future<void> deleteComment(String commentId, {String? announcementId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deleted = (prefs.getStringList(_deletedCommentsKey) ?? []).toSet();
      deleted.add(commentId);
      await prefs.setStringList(_deletedCommentsKey, deleted.toList());

      if (announcementId != null) {
        final key = '$_localCommentsKeyPrefix$announcementId';
        final list = prefs.getStringList(key) ?? [];
        list.removeWhere((item) {
          try {
            final map = jsonDecode(item) as Map<String, dynamic>;
            return map['id'] == commentId;
          } catch (_) {
            return false;
          }
        });
        await prefs.setStringList(key, list);
      }
    } catch (_) {}

    try {
      await _supabase.from('announcement_comments').delete().eq('id', commentId);
    } catch (_) {}

    if (announcementId != null) {
      try {
        final token = await _getBackgroundAccessToken();
        final supabaseUrl = dotenv.env[AppConstants.supabaseUrlEnvKey] ?? '';
        final anonKey = dotenv.env[AppConstants.supabaseAnonKeyEnvKey] ?? '';
        if (token != null && supabaseUrl.isNotEmpty && anonKey.isNotEmpty) {
          await _syncCommentsToCloudAnnouncement(
            announcementId: announcementId,
            token: token,
            supabaseUrl: supabaseUrl,
            anonKey: anonKey,
          );
        }
      } catch (_) {}
    }
  }
}