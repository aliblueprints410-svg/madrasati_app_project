import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/school.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  static const String _sysTeacherSchoolPrefix = '__SYS_TEACHER_SCHOOL__:';

  // Check if school code exists and is valid (case-insensitive)
  Future<School?> verifySchoolCode(String code) async {
    try {
      final cleanCode = code.trim();
      final response = await _supabase
          .from('schools')
          .select()
          .ilike('school_code', cleanCode)
          .maybeSingle();

      if (response != null) {
        return School.fromJson(response);
      }
      return null;
    } catch (e) {
      throw Exception('فشل في التحقق من كود المدرسة: $e');
    }
  }

  // Fetch school details by UUID or school code
  Future<School?> getSchoolById(String schoolIdOrCode) async {
    try {
      final clean = schoolIdOrCode.trim();
      if (clean.isEmpty) return null;
      final byId = await _supabase
          .from('schools')
          .select()
          .eq('id', clean)
          .maybeSingle();
      if (byId != null) {
        return School.fromJson(byId);
      }
      final byCode = await _supabase
          .from('schools')
          .select()
          .ilike('school_code', clean)
          .maybeSingle();
      if (byCode != null) {
        return School.fromJson(byCode);
      }
    } catch (_) {}
    return null;
  }

  // Teacher Login with strict School Binding & Isolation
  Future<School> loginTeacherWithSchool({
    required String email,
    required String password,
    required String schoolCode,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanCode = schoolCode.trim();

    // 1. Verify school code exists
    final school = await verifySchoolCode(cleanCode);
    if (school == null) {
      throw Exception('كود المدرسة غير صحيح! يرجى التأكد من كود المدرسة.');
    }

    // 2. Authenticate teacher credentials
    AuthResponse authRes;
    try {
      authRes = await _supabase.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );
    } catch (_) {
      throw Exception('فشل تسجيل الدخول. تأكد من البريد الإلكتروني وكلمة المرور.');
    }

    final user = authRes.user;
    String? boundSchoolId = user?.userMetadata?['school_id']?.toString();
    String? boundSchoolCode = user?.userMetadata?['school_code']?.toString();
    String? boundSchoolName = user?.userMetadata?['school_name']?.toString();

    // 3. Also check cloud teacher-school binding registry
    final sysTitle = '$_sysTeacherSchoolPrefix$cleanEmail';
    try {
      final rows = await _supabase
          .from('announcements')
          .select('content')
          .eq('title', sysTitle)
          .order('created_at', ascending: false)
          .limit(1);

      if ((rows as List).isNotEmpty) {
        final raw = rows.first['content'] as String?;
        if (raw != null && raw.isNotEmpty) {
          final map = jsonDecode(raw) as Map<String, dynamic>;
          boundSchoolId ??= map['school_id']?.toString();
          boundSchoolCode ??= map['school_code']?.toString();
          boundSchoolName ??= map['school_name']?.toString();
        }
      }
    } catch (_) {}

    // 4. Enforce strict separation: reject if teacher is bound to a different school
    if (boundSchoolId != null &&
        boundSchoolId.isNotEmpty &&
        boundSchoolId != school.id) {
      await _supabase.auth.signOut();
      final otherLabel = boundSchoolName ?? boundSchoolCode ?? 'مدرسة أخرى';
      throw Exception(
        'عذراً، حساب الأستاذ هذا تابع لـ ($otherLabel) ولا يمكنه الدخول إلى (${school.name})!',
      );
    }

    if (boundSchoolCode != null &&
        boundSchoolCode.isNotEmpty &&
        boundSchoolCode.toLowerCase() != school.schoolCode.toLowerCase()) {
      await _supabase.auth.signOut();
      final otherLabel = boundSchoolName ?? boundSchoolCode;
      throw Exception(
        'عذراً، حساب الأستاذ هذا تابع لـ ($otherLabel) ولا يمكنه الدخول إلى (${school.name})!',
      );
    }

    // 5. Bind teacher account permanently to this school if not yet bound
    if (boundSchoolId == null || boundSchoolId.isEmpty) {
      try {
        await _supabase.auth.updateUser(
          UserAttributes(
            data: {
              'school_id': school.id,
              'school_code': school.schoolCode,
              'school_name': school.name,
            },
          ),
        );
      } catch (_) {}

      try {
        await _supabase.from('announcements').insert({
          'id': const Uuid().v4(),
          'school_id': school.id,
          'title': sysTitle,
          'content': jsonEncode({
            'email': cleanEmail,
            'school_id': school.id,
            'school_code': school.schoolCode,
            'school_name': school.name,
          }),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'priority': false,
          'is_deleted': false,
        });
      } catch (_) {}
    }

    return school;
  }

  // Legacy loginTeacher fallback
  Future<AuthResponse> loginTeacher(String email, String password) async {
    try {
      return await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('فشل تسجيل الدخول. تأكد من البريد وكلمة المرور.');
    }
  }

  // Teacher Logout
  Future<void> logout() async {
    await _supabase.auth.signOut();
  }

  // Get current user (Teacher)
  User? get currentUser => _supabase.auth.currentUser;
}
