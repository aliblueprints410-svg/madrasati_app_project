import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/core_providers.dart';
import '../services/homework_service.dart';
import '../models/school_class.dart';
import '../models/subject.dart';
import '../models/homework.dart';

// Service Provider
final homeworkServiceProvider = Provider<HomeworkService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return HomeworkService(supabase);
});

// Future Providers for Classes and Subjects (Depends on selected school/class)
final classesProvider = FutureProvider.family<List<SchoolClass>, String>((ref, schoolId) async {
  final service = ref.watch(homeworkServiceProvider);
  return service.getClasses(schoolId);
});

final subjectsProvider = FutureProvider.family<List<Subject>, String>((ref, classId) async {
  final service = ref.watch(homeworkServiceProvider);
  return service.getSubjects(classId);
});

// Future Providers for Homework (prevents Realtime stream reconnect loops & image flickering)
final currentHomeworkProvider = FutureProvider.family<List<Homework>, String>((ref, subjectId) async {
  final service = ref.watch(homeworkServiceProvider);
  return service.getCurrentHomework(subjectId);
});

final homeworkArchiveProvider = FutureProvider.family<List<Homework>, String>((ref, subjectId) async {
  final service = ref.watch(homeworkServiceProvider);
  return service.getHomeworkArchive(subjectId);
});

final studentCompletedHomeworkIdsProvider = FutureProvider<Set<String>>((ref) async {
  final service = ref.watch(homeworkServiceProvider);
  return service.getStudentCompletedHomeworkIds();
});

/// Checks whether a subject has new unread/unopened homework
final subjectHasUnreadHomeworkProvider = FutureProvider.family<bool, String>((ref, subjectId) async {
  try {
    final currentHw = await ref.watch(currentHomeworkProvider(subjectId).future);
    if (currentHw.isEmpty) return false;

    final prefs = ref.watch(sharedPreferencesProvider);
    final lastViewed = prefs.getInt('subject_last_viewed_$subjectId') ?? 0;

    for (final hw in currentHw) {
      if (hw.createdAt.millisecondsSinceEpoch > lastViewed) {
        return true;
      }
    }
  } catch (_) {}
  return false;
});


