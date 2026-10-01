class AppConstants {
  static const String appName = 'مدرستي';
  static const String appVersion = 'v 2.0.2';
  
  // Default School UUID (Primary School 1 - SCH-1)
  static const String defaultSchoolId = 'd581107e-2f01-4bd0-a89d-bf27f36a2574';
  
  // Developer Info
  static const String developerName = 'علي';
  static const String developerTelegramUrl = 'https://t.me/Ali_Muhammed_410';
  static const String developerTelegramUsername = '@Ali_Muhammed_410';
  static const String developerWhatsapp = '+9647749509636';
  static const String developerWhatsappUrl = 'https://wa.me/9647749509636';
  static const String developerFacebookUrl = 'https://www.facebook.com/profile.php?id=61594838129624';

  static const String supabaseUrlEnvKey = 'SUPABASE_URL';
  static const String supabaseAnonKeyEnvKey = 'SUPABASE_ANON_KEY';

  // Local Storage Keys
  static const String keySchoolCode = 'school_code';
  static const String keySchoolName = 'school_name';
  static const String keySchoolShortCode = 'school_short_code';
  static const String keyStudentName = 'student_name';
  static const String keySelectedGrade = 'selected_grade';

  /// Returns a valid 36-char UUID, falling back safely to defaultSchoolId
  static String sanitizeSchoolId(String? rawId) {
    if (rawId != null && RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(rawId)) {
      return rawId;
    }
    return defaultSchoolId;
  }
}