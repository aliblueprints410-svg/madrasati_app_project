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

// Stream Providers for Homework
final currentHomeworkProvider = StreamProvider.family<List<Homework>, String>((ref, subjectId) {
  final service = ref.watch(homeworkServiceProvider);
  return service.watchCurrentHomework(subjectId);
});

final homeworkArchiveProvider = StreamProvider.family<List<Homework>, String>((ref, subjectId) {
  final service = ref.watch(homeworkServiceProvider);
  return service.watchHomeworkArchive(subjectId);
});
