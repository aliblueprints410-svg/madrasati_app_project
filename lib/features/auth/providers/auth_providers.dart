import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../services/auth_service.dart';
import '../models/school.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AuthService(supabase);
});

// Provider to hold the current school code logic state
final authStateProvider = StateProvider<bool>((ref) => false);

// Resolves the currently logged-in school (both for Student and Teacher)
final activeSchoolProvider = FutureProvider.autoDispose<School?>((ref) async {
  final localStorage = ref.watch(localStorageServiceProvider);
  final schoolId = localStorage.getSchoolCode();
  if (schoolId == null || schoolId.isEmpty) return null;

  final authService = ref.watch(authServiceProvider);
  final fetched = await authService.getSchoolById(schoolId);
  if (fetched != null) {
    await localStorage.saveSchoolName(fetched.name);
    await localStorage.saveSchoolShortCode(fetched.schoolCode);
    return fetched;
  }

  final cachedName = localStorage.getSchoolName();
  final cachedShortCode = localStorage.getSchoolShortCode();
  if (cachedName != null && cachedName.isNotEmpty) {
    return School(
      id: schoolId,
      name: cachedName,
      schoolCode: cachedShortCode ?? '',
    );
  }
  return null;
});

