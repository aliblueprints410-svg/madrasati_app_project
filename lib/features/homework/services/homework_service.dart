import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/homework.dart';
import '../models/school_class.dart';
import '../models/subject.dart';

class HomeworkService {
  final SupabaseClient _supabase;

  HomeworkService(this._supabase);

  // Return official Iraqi primary curriculum subjects based on grade name
  List<String> getSubjectsListForGrade(String gradeName) {
    final name = gradeName.toLowerCase();
    if (name.contains('اول') || name.contains('أول') ||
        name.contains('ثاني') ||
        name.contains('ثالث') ||
        name.contains('1') || name.contains('2') || name.contains('3')) {
      return [
        'التربية الاسلامية',
        'القراءة',
        'الرياضيات',
        'العلوم',
        'اللغة الانكليزية',
        'الاخلاقيه',
        'التربية الرياضية',
        'التربية الفنية',
      ];
    } else {
      // صف رابع، خامس، سادس
      return [
        'التربية الاسلامية',
        'اللغة العربية',
        'الرياضيات',
        'العلوم',
        'اللغة الانكليزية',
        'الاجتماعيات',
        'التربية الرياضية',
        'التربية الفنية',
      ];
    }
  }

  // Get classes for a specific school
  Future<List<SchoolClass>> getClasses(String schoolId) async {
    try {
      final response = await _supabase
          .from('classes')
          .select()
          .eq('school_id', schoolId)
          .order('order', ascending: true);

      return (response as List).map((e) => SchoolClass.fromJson(e)).toList();
    } catch (e) {
      throw Exception('خطأ في جلب الصفوف: $e');
    }
  }

  // Get subjects for a specific class (with curriculum fallback)
  Future<List<Subject>> getSubjects(String classId) async {
    try {
      final response = await _supabase
          .from('subjects')
          .select()
          .eq('class_id', classId);

      final list = (response as List).map((e) => Subject.fromJson(e)).toList();
      if (list.isNotEmpty) {
        return list;
      }

      // If empty in database, get class name to return official grade subjects
      return await _generateFallbackSubjects(classId);
    } catch (_) {
      return await _generateFallbackSubjects(classId);
    }
  }

  Future<List<Subject>> _generateFallbackSubjects(String classId) async {
    String gradeName = '';
    try {
      final classRes = await _supabase
          .from('classes')
          .select('name')
          .eq('id', classId)
          .maybeSingle();
      if (classRes != null && classRes['name'] != null) {
        gradeName = classRes['name'] as String;
      }
    } catch (_) {}

    final subjectNames = getSubjectsListForGrade(gradeName);
    return subjectNames.map((name) {
      final deterministicId = 'subj_${classId.hashCode.abs()}_${name.hashCode.abs()}';
      return Subject(
        id: deterministicId,
        classId: classId,
        name: name,
      );
    }).toList();
  }

  // Seed default primary subjects for a specific class to Supabase (Teacher only)
  Future<void> seedDefaultSubjectsForClass(String classId, String className) async {
    final names = getSubjectsListForGrade(className);
    const uuid = Uuid();
    final records = names.map((name) => {
      'id': uuid.v4(),
      'class_id': classId,
      'name': name,
    }).toList();

    await _supabase.from('subjects').insert(records);
  }

  // Fetch active homework safely via REST
  Future<List<Homework>> getCurrentHomework(String subjectId) async {
    try {
      final res = await _supabase
          .from('homework')
          .select()
          .eq('subject_id', subjectId)
          .eq('is_current', true)
          .eq('is_deleted', false);
      return (res as List).map((e) => Homework.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // Get active homework for a subject with safe fallback
  Stream<List<Homework>> watchCurrentHomework(String subjectId) async* {
    yield await getCurrentHomework(subjectId);

    try {
      final stream = _supabase
          .from('homework')
          .stream(primaryKey: ['id'])
          .eq('subject_id', subjectId)
          .eq('is_current', true)
          .eq('is_deleted', false)
          .map((data) => data.map((e) => Homework.fromJson(e)).toList())
          .handleError((error) {
            debugPrint('[HomeworkService] Realtime homework notice: $error');
          });

      yield* stream;
    } catch (_) {
      yield await getCurrentHomework(subjectId);
    }
  }

  // Fetch archive homework safely via REST
  Future<List<Homework>> getHomeworkArchive(String subjectId) async {
    try {
      final res = await _supabase
          .from('homework')
          .select()
          .eq('subject_id', subjectId)
          .eq('is_current', false)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);
      return (res as List).map((e) => Homework.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // Get homework archive with safe fallback
  Stream<List<Homework>> watchHomeworkArchive(String subjectId) async* {
    yield await getHomeworkArchive(subjectId);

    try {
      final stream = _supabase
          .from('homework')
          .stream(primaryKey: ['id'])
          .eq('subject_id', subjectId)
          .eq('is_current', false)
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .map((data) => data.map((e) => Homework.fromJson(e)).toList())
          .handleError((error) {
            debugPrint('[HomeworkService] Realtime archive notice: $error');
          });

      yield* stream;
    } catch (_) {
      yield await getHomeworkArchive(subjectId);
    }
  }

  // Add homework (Teacher)
  Future<void> addHomework(Homework homework) async {
    try {
      await _supabase.from('homework').insert(homework.toJson());
    } catch (e) {
      if (e.toString().contains('deadline') || e.toString().contains('PGRST204')) {
        // Fallback if 'deadline' column is not in DB table
        final data = homework.toJson()..remove('deadline');
        if (homework.deadline != null) {
          final deadlineStr = DateFormat('yyyy-MM-dd • hh:mm a').format(homework.deadline!)
              .replaceAll('AM', 'صباحاً')
              .replaceAll('PM', 'مساءً');
          data['description'] = '${homework.description}\n\n⏰ موعد التسليم: $deadlineStr';
        }
        await _supabase.from('homework').insert(data);
        return;
      }
      throw Exception('فشل في إضافة الواجب: $e');
    }
  }

  // Archive homework (Mark as not current)
  Future<void> archiveHomework(String id) async {
    try {
      await _supabase.from('homework').update({'is_current': false}).eq('id', id);
    } catch (e) {
      throw Exception('فشل في أرشفة الواجب: $e');
    }
  }

  // Delete homework (Soft delete)
  Future<void> deleteHomework(String id) async {
    try {
      await _supabase.from('homework').update({'is_deleted': true}).eq('id', id);
    } catch (e) {
      throw Exception('فشل في حذف الواجب: $e');
    }
  }
}