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
