import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/school.dart';

class AuthService {
  final SupabaseClient _supabase;

  AuthService(this._supabase);

  // Check if school code exists and is valid
  Future<School?> verifySchoolCode(String code) async {
    try {
      final response = await _supabase
          .from('schools')
          .select()
          .eq('school_code', code)
          .maybeSingle();
          
      if (response != null) {
        return School.fromJson(response);
      }
      return null;
    } catch (e) {
      throw Exception('فشل في التحقق من كود المدرسة: $e');
    }
  }

  // Teacher Login
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
