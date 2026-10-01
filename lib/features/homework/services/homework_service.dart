import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/arabic_day_helper.dart';
import '../models/homework.dart';
import '../models/school_class.dart';
import '../models/subject.dart';

class HomeworkService {
  final SupabaseClient _supabase;

  HomeworkService(this._supabase);

  static const String _sysSubjectsPrefix = '__SYS_SUBJECTS_V2__:';
  static const String _localSubjectsKeyPrefix = 'subjects_v2_override_';
  static const String _localSubjectsRevKeyPrefix = 'subjects_v2_rev_';
  static const String _sysHomeworkPrefix = '__SYS_HOMEWORK__:';
  static const String _localHomeworkKeyPrefix = 'local_homework_';
  static const String _archivedHomeworkIdsKey = 'archived_homework_ids';

  ({int rev, List<Subject> subjects})? _parseSubjectsPayload(String? raw, int fallbackRev) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final rev = (decoded['rev'] is num) ? (decoded['rev'] as num).toInt() : fallbackRev;
        final rawList = decoded['subjects'] as List? ?? [];
        final list = rawList
            .map((e) => Subject.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return (rev: rev, subjects: list);
      } else if (decoded is List) {
        final list = decoded
            .map((e) => Subject.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return (rev: fallbackRev, subjects: list);
      }
    } catch (_) {}
    return null;
  }

  // Return official curriculum subjects based on grade name
  List<String> getSubjectsListForGrade(String gradeName) {
    final name = gradeName.toLowerCase();

    // المرحلة المتوسطة
    if (name.contains('متوسط')) {
      if (name.contains('ثالث') || name.contains('3')) {
        return [
          'الاسلامية',
          'العربية',
          'الانكليزية',
          'الاجتماعيات',
          'الرياضيات',
          'الاحياء',
          'الفيزياء',
          'الكيمياء',
          'الفنية',
          'الرياضة',
        ];
      } else {
        // صف أول وثاني متوسط
        return [
          'الاسلامية',
          'العربية',
          'الانكليزية',
          'الاجتماعيات',
          'الرياضيات',
          'الاحياء',
          'الفيزياء',
          'الكيمياء',
          'الاخلاقية',
          'الفنية',
          'الرياضة',
        ];
      }
    }

    // المرحلة الابتدائية (يبقى كما هو بدون أي تغيير)
    if (name.contains('اول') ||
        name.contains('أول') ||
        name.contains('ثاني') ||
        name.contains('ثالث') ||
        name.contains('1') ||
        name.contains('2') ||
        name.contains('3')) {
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

  // Get classes for a specific school (with automatic provisioning for new schools)
  Future<List<SchoolClass>> getClasses(String schoolId) async {
    final cleanSchoolId = AppConstants.sanitizeSchoolId(schoolId);
    try {
      final response = await _supabase
          .from('classes')
          .select()
          .eq('school_id', cleanSchoolId)
          .order('order', ascending: true);

      final list = (response as List).map((e) => SchoolClass.fromJson(e)).toList();
      if (list.isNotEmpty) {
        return list;
      }
    } catch (_) {}

    // Special middle school provisioning if schoolId is ANAWEEN-1
    if (cleanSchoolId == AppConstants.anaweenSchoolId ||
        schoolId.toUpperCase().contains('ANAWEEN')) {
      const middleGradeNames = [
        'الصف الأول المتوسط',
        'الصف الثاني المتوسط',
        'الصف الثالث المتوسط',
      ];
      const anaweenClassIds = [
        'c1111111-1111-4111-8111-111111111111',
        'c2222222-2222-4222-8222-222222222222',
        'c3333333-3333-4333-8333-333333333333',
      ];
      final List<SchoolClass> middleClasses = [];
      final List<Map<String, dynamic>> toInsertMiddle = [];
      for (int i = 0; i < middleGradeNames.length; i++) {
        final order = i + 1;
        final cId = anaweenClassIds[i];
        middleClasses.add(
          SchoolClass(
            id: cId,
            schoolId: AppConstants.anaweenSchoolId,
            name: middleGradeNames[i],
            order: order,
          ),
        );
        toInsertMiddle.add({
          'id': cId,
          'school_id': AppConstants.anaweenSchoolId,
          'name': middleGradeNames[i],
          'order': order,
        });
      }
      try {
        await _supabase.from('classes').insert(toInsertMiddle);
      } catch (_) {}
      return middleClasses;
    }

    // Auto-provision 6 isolated primary classes for this schoolId if not yet in DB
    const gradeNames = [
      'الصف الأول الابتدائي',
      'الصف الثاني الابتدائي',
      'الصف الثالث الابتدائي',
      'الصف الرابع الابتدائي',
      'الصف الخامس الابتدائي',
      'الصف السادس الابتدائي',
    ];
    const uuid = Uuid();
    final List<SchoolClass> generated = [];
    final List<Map<String, dynamic>> toInsert = [];

    for (int i = 0; i < gradeNames.length; i++) {
      final order = i + 1;
      final detId = uuid.v5(Namespace.url.value, 'madrasati_class_${cleanSchoolId}_$order');
      generated.add(
        SchoolClass(
          id: detId,
          schoolId: cleanSchoolId,
          name: gradeNames[i],
          order: order,
        ),
      );
      toInsert.add({
        'id': detId,
        'school_id': cleanSchoolId,
        'name': gradeNames[i],
        'order': order,
      });
    }

    try {
      await _supabase.from('classes').insert(toInsert);
    } catch (_) {}

    return generated;
  }

  // Get subjects for a specific class (with monotonic revision comparison between local & cloud)
  Future<List<Subject>> getSubjects(String classId) async {
    ({int rev, List<Subject> subjects})? localParsed;

    try {
      final prefs = await SharedPreferences.getInstance();
      final localRaw = prefs.getString('$_localSubjectsKeyPrefix$classId');
      final localRev = prefs.getInt('$_localSubjectsRevKeyPrefix$classId') ?? 0;
      localParsed = _parseSubjectsPayload(localRaw, localRev);
    } catch (_) {}

    // 1. Check cloud overrides in announcements system rows and find highest revision
    ({int rev, List<Subject> subjects})? cloudBest;
    String? cloudBestRaw;
    try {
      final sysTitle = '$_sysSubjectsPrefix$classId';
      final sysRows = await _supabase
          .from('announcements')
          .select('content, created_at')
          .eq('title', sysTitle)
          .order('created_at', ascending: false)
          .limit(10);

      for (final row in (sysRows as List)) {
        final rawContent = row['content'] as String?;
        final createdAtStr = row['created_at'] as String?;
        final fallbackTs = createdAtStr != null
            ? (DateTime.tryParse(createdAtStr)?.millisecondsSinceEpoch ?? 0)
            : 0;
        final parsed = _parseSubjectsPayload(rawContent, fallbackTs);
        if (parsed != null && (cloudBest == null || parsed.rev > cloudBest.rev)) {
          cloudBest = parsed;
          cloudBestRaw = rawContent;
        }
      }
    } catch (_) {}

    if (cloudBest != null && (localParsed == null || cloudBest.rev > localParsed.rev)) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (cloudBestRaw != null) {
          await prefs.setString('$_localSubjectsKeyPrefix$classId', cloudBestRaw);
        }
        await prefs.setInt('$_localSubjectsRevKeyPrefix$classId', cloudBest.rev);
      } catch (_) {}
      return cloudBest.subjects;
    }

    // 2. Return local override if present (and >= cloudBest.rev)
    if (localParsed != null) {
      return localParsed.subjects;
    }

    // 3. Query subjects table in Supabase
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

  Future<void> _saveSubjectsOverride(String classId, List<Subject> subjects) async {
    final nowUtc = DateTime.now().toUtc();
    final nowMs = nowUtc.millisecondsSinceEpoch;
    int prevRev = 0;
    String schoolId = AppConstants.defaultSchoolId;

    try {
      final prefs = await SharedPreferences.getInstance();
      prevRev = prefs.getInt('$_localSubjectsRevKeyPrefix$classId') ?? 0;
      schoolId = AppConstants.sanitizeSchoolId(prefs.getString(AppConstants.keySchoolCode));
    } catch (_) {}

    final newRev = (prevRev >= nowMs ? prevRev : nowMs) + 1;
    final payloadStr = jsonEncode({
      'rev': newRev,
      'subjects': subjects.map((s) => s.toJson()).toList(),
    });

    // 1. Save locally with strictly higher monotonic revision
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_localSubjectsKeyPrefix$classId', payloadStr);
      await prefs.setInt('$_localSubjectsRevKeyPrefix$classId', newRev);
    } catch (_) {}

    // 2. Sync to cloud via append-only INSERT into announcements
    try {
      final sysTitle = '$_sysSubjectsPrefix$classId';
      await _supabase.from('announcements').insert({
        'id': const Uuid().v4(),
        'school_id': schoolId,
        'title': sysTitle,
        'content': payloadStr,
        'created_at': nowUtc.toIso8601String(),
        'priority': false,
        'is_deleted': false,
      });
    } catch (e) {
      debugPrint('[HomeworkService] Cloud subjects sync notice: $e');
    }
  }

  // Add a new subject for a class (Teacher)
  Future<void> addSubject(String classId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final current = await getSubjects(classId);
    final newSubject = Subject(
      id: const Uuid().v4(),
      classId: classId,
      name: trimmed,
    );

    try {
      await _supabase.from('subjects').insert({
        'id': newSubject.id,
        'class_id': classId,
        'name': trimmed,
      });
    } catch (e) {
      debugPrint('[HomeworkService] Direct addSubject fallback: $e');
    }

    await _saveSubjectsOverride(classId, [...current, newSubject]);
  }

  // Update an existing subject name (Teacher)
  Future<void> updateSubject(
    String classId,
    String subjectId,
    String newName, {
    String? oldName,
  }) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return;

    final current = await getSubjects(classId);
    bool matched = false;
    final updated = current.map((s) {
      if (s.id == subjectId ||
          (!matched && oldName != null && s.name.trim() == oldName.trim())) {
        matched = true;
        return Subject(id: s.id, classId: s.classId, name: trimmed, icon: s.icon);
      }
      return s;
    }).toList();

    try {
      await _supabase
          .from('subjects')
          .update({'name': trimmed})
          .eq('id', subjectId);
    } catch (e) {
      debugPrint('[HomeworkService] Direct updateSubject fallback: $e');
    }

    await _saveSubjectsOverride(classId, updated);
  }

  // Delete a subject (Teacher)
  Future<void> deleteSubject(String classId, String subjectId) async {
    final current = await getSubjects(classId);
    final updated = current.where((s) => s.id != subjectId).toList();

    try {
      await _supabase.from('subjects').delete().eq('id', subjectId);
    } catch (e) {
      debugPrint('[HomeworkService] Direct deleteSubject fallback: $e');
    }

    await _saveSubjectsOverride(classId, updated);
  }

  Future<List<Subject>> _generateFallbackSubjects(String classId) async {
    String gradeName = '';
    if (classId == 'c1111111-1111-4111-8111-111111111111') {
      gradeName = 'الصف الأول المتوسط';
    } else if (classId == 'c2222222-2222-4222-8222-222222222222') {
      gradeName = 'الصف الثاني المتوسط';
    } else if (classId == 'c3333333-3333-4333-8333-333333333333') {
      gradeName = 'الصف الثالث المتوسط';
    } else {
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
    }

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

  // Seed default primary subjects for a specific class to Supabase (Teacher)
  Future<void> seedDefaultSubjectsForClass(String classId, String className) async {
    final officialNames = getSubjectsListForGrade(className);
    const uuid = Uuid();

    // Fetch existing DB subjects first so we preserve real DB UUIDs if they exist
    List<Subject> dbSubjects = [];
    try {
      final response = await _supabase
          .from('subjects')
          .select()
          .eq('class_id', classId);
      dbSubjects = (response as List).map((e) => Subject.fromJson(e)).toList();
    } catch (_) {}

    final current = await getSubjects(classId);
    final List<Subject> merged = List<Subject>.from(current);
    final List<Map<String, dynamic>> toInsert = [];

    for (final name in officialNames) {
      final exists = merged.any((s) => s.name.trim() == name.trim());
      if (!exists) {
        final dbMatch = dbSubjects.where((s) => s.name.trim() == name.trim()).toList();
        final newId = dbMatch.isNotEmpty ? dbMatch.first.id : uuid.v4();
        final subj = Subject(id: newId, classId: classId, name: name);
        merged.add(subj);
        if (dbMatch.isEmpty) {
          toInsert.add({
            'id': newId,
            'class_id': classId,
            'name': name,
          });
        }
      }
    }

    if (toInsert.isNotEmpty) {
      try {
        await _supabase.from('subjects').insert(toInsert);
      } catch (e) {
        debugPrint('[HomeworkService] Direct seedDefaultSubjects fallback: $e');
      }
    }

    await _saveSubjectsOverride(classId, merged);
  }

  static const String _sysResetYearPrefix = '__SYS_RESET_YEAR__:';

  /// Returns homework IDs completed locally by the student on THIS device only.
  Future<Set<String>> getStudentCompletedHomeworkIds([String? schoolId]) async {
    final Set<String> ids = {};
    try {
      final prefs = await SharedPreferences.getInstance();
      final cleanSchoolId = AppConstants.sanitizeSchoolId(
        schoolId ?? prefs.getString(AppConstants.keySchoolCode),
      );
      ids.addAll(prefs.getStringList('${_archivedHomeworkIdsKey}_$cleanSchoolId') ?? []);
      if (cleanSchoolId == AppConstants.defaultSchoolId) {
        ids.addAll(prefs.getStringList(_archivedHomeworkIdsKey) ?? []);
      }
    } catch (_) {}
    return ids;
  }

  Future<DateTime?> _getSchoolResetTimestamp([String? schoolId]) async {
    String cleanSchoolId = AppConstants.defaultSchoolId;
    DateTime? localResetTs;

    try {
      final prefs = await SharedPreferences.getInstance();
      cleanSchoolId = AppConstants.sanitizeSchoolId(
        schoolId ?? prefs.getString(AppConstants.keySchoolCode),
      );
      final localRaw = prefs.getString('reset_year_ts_$cleanSchoolId');
      if (localRaw != null && localRaw.isNotEmpty) {
        localResetTs = DateTime.tryParse(localRaw)?.toUtc();
      }
    } catch (_) {}

    try {
      final sysTitle = '$_sysResetYearPrefix$cleanSchoolId';
      final rows = await _supabase
          .from('announcements')
          .select('content')
          .eq('title', sysTitle)
          .order('created_at', ascending: false)
          .limit(5);

      DateTime? cloudBest;
      for (final r in (rows as List)) {
        final raw = r['content']?.toString();
        if (raw != null && raw.isNotEmpty) {
          final parsed = DateTime.tryParse(raw)?.toUtc();
          if (parsed != null && (cloudBest == null || parsed.isAfter(cloudBest))) {
            cloudBest = parsed;
          }
        }
      }

      if (cloudBest != null && (localResetTs == null || cloudBest.isAfter(localResetTs))) {
        localResetTs = cloudBest;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('reset_year_ts_$cleanSchoolId', cloudBest.toIso8601String());
      }
    } catch (_) {}

    return localResetTs;
  }

  Future<Set<String>> _getSchoolSubjectIds(String schoolId) async {
    final cleanSchoolId = AppConstants.sanitizeSchoolId(schoolId);
    final Set<String> subjectIds = {};
    try {
      final classes = await getClasses(cleanSchoolId);
      for (final c in classes) {
        final subs = await getSubjects(c.id);
        for (final s in subs) {
          subjectIds.add(s.id);
        }
      }
      if (classes.isNotEmpty) {
        final classIds = classes.map((c) => c.id).toList();
        final dbSubs = await _supabase
            .from('subjects')
            .select('id')
            .inFilter('class_id', classIds);
        for (final row in (dbSubs as List)) {
          final id = row['id']?.toString();
          if (id != null && id.isNotEmpty) {
            subjectIds.add(id);
          }
        }
      }
    } catch (_) {}
    return subjectIds;
  }

  // Get active and expired/completed homework counts for Teacher Dashboard
  // Teacher completion depends ONLY on whether the homework's deadline time has expired (not single student completion!)
  Future<Map<String, int>> getDashboardHomeworkStats([String? schoolId]) async {
    String cleanSchoolId = AppConstants.defaultSchoolId;
    try {
      final prefs = await SharedPreferences.getInstance();
      cleanSchoolId = AppConstants.sanitizeSchoolId(
        schoolId ?? prefs.getString(AppConstants.keySchoolCode),
      );
    } catch (_) {}

    final schoolSubjectIds = await _getSchoolSubjectIds(cleanSchoolId);
    final resetTs = await _getSchoolResetTimestamp(cleanSchoolId);
    final Map<String, Homework> allHomeworks = {};

    try {
      final hwRes = await _supabase
          .from('homework')
          .select()
          .eq('is_deleted', false);
      for (final e in (hwRes as List)) {
        final hw = Homework.fromJson(Map<String, dynamic>.from(e as Map));
        if (schoolSubjectIds.contains(hw.subjectId) &&
            (resetTs == null || !hw.createdAt.toUtc().isBefore(resetTs))) {
          allHomeworks[hw.id] = hw;
        }
      }
    } catch (_) {}

    try {
      final sysRows = await _supabase
          .from('announcements')
          .select('content')
          .like('title', '$_sysHomeworkPrefix%')
          .order('created_at', ascending: false)
          .limit(25);
      for (final row in (sysRows as List)) {
        final raw = row['content'] as String?;
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List;
          for (final e in list) {
            final hw = Homework.fromJson(Map<String, dynamic>.from(e as Map));
            if (!hw.isDeleted &&
                schoolSubjectIds.contains(hw.subjectId) &&
                (resetTs == null || !hw.createdAt.toUtc().isBefore(resetTs))) {
              allHomeworks[hw.id] = hw;
            }
          }
        }
      }
    } catch (_) {}

    int activeCount = 0;
    int completedCount = 0;
    for (final hw in allHomeworks.values) {
      if (hw.isExpired || !hw.isCurrent) {
        completedCount++;
      } else {
        activeCount++;
      }
    }

    return {
      'active': activeCount,
      'completed': completedCount,
    };
  }

  // Get all expired/completed homework items across subjects for Teacher Dashboard
  Future<List<Homework>> getAllCompletedHomework([String? schoolId]) async {
    String cleanSchoolId = AppConstants.defaultSchoolId;
    try {
      final prefs = await SharedPreferences.getInstance();
      cleanSchoolId = AppConstants.sanitizeSchoolId(
        schoolId ?? prefs.getString(AppConstants.keySchoolCode),
      );
    } catch (_) {}

    final schoolSubjectIds = await _getSchoolSubjectIds(cleanSchoolId);
    final resetTs = await _getSchoolResetTimestamp(cleanSchoolId);
    final Map<String, Homework> completed = {};

    try {
      final hwRes = await _supabase
          .from('homework')
          .select()
          .eq('is_deleted', false)
          .order('created_at', ascending: false);
      for (final e in (hwRes as List)) {
        final hw = Homework.fromJson(Map<String, dynamic>.from(e as Map));
        if (schoolSubjectIds.contains(hw.subjectId) &&
            (resetTs == null || !hw.createdAt.toUtc().isBefore(resetTs)) &&
            (hw.isExpired || !hw.isCurrent)) {
          completed[hw.id] = hw;
        }
      }
    } catch (_) {}

    try {
      final sysRows = await _supabase
          .from('announcements')
          .select('content')
          .like('title', '$_sysHomeworkPrefix%')
          .order('created_at', ascending: false)
          .limit(25);
      for (final row in (sysRows as List)) {
        final raw = row['content'] as String?;
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List;
          for (final e in list) {
            final hw = Homework.fromJson(Map<String, dynamic>.from(e as Map));
            if (!hw.isDeleted &&
                schoolSubjectIds.contains(hw.subjectId) &&
                (resetTs == null || !hw.createdAt.toUtc().isBefore(resetTs)) &&
                (hw.isExpired || !hw.isCurrent)) {
              completed[hw.id] = hw;
            }
          }
        }
      }
    } catch (_) {}

    final list = completed.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // Load fallback homework list for custom subjects
  Future<List<Homework>> _getFallbackHomeworkForSubject(String subjectId) async {
    final Map<String, Homework> merged = {};

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_localHomeworkKeyPrefix$subjectId');
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        for (final e in list) {
          final hw = Homework.fromJson(e as Map<String, dynamic>);
          merged[hw.id] = hw;
        }
      }
    } catch (_) {}

    try {
      final sysTitle = '$_sysHomeworkPrefix$subjectId';
      final sysRows = await _supabase
          .from('announcements')
          .select('content')
          .eq('title', sysTitle)
          .order('created_at', ascending: false)
          .limit(1);

      if ((sysRows as List).isNotEmpty) {
        final raw = sysRows.first['content'] as String?;
        if (raw != null && raw.isNotEmpty) {
          final list = jsonDecode(raw) as List;
          for (final e in list) {
            final hw = Homework.fromJson(e as Map<String, dynamic>);
            merged[hw.id] = hw;
          }
        }
      }
    } catch (_) {}

    return merged.values.toList();
  }

  Future<void> _saveFallbackHomeworkForSubject(String subjectId, List<Homework> list) async {
    final jsonStr = jsonEncode(list.map((h) => h.toJson()).toList());
    String schoolId = AppConstants.defaultSchoolId;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_localHomeworkKeyPrefix$subjectId', jsonStr);
      schoolId = AppConstants.sanitizeSchoolId(prefs.getString(AppConstants.keySchoolCode));
    } catch (_) {}

    try {
      final sysTitle = '$_sysHomeworkPrefix$subjectId';
      await _supabase.from('announcements').insert({
        'id': const Uuid().v4(),
        'school_id': schoolId,
        'title': sysTitle,
        'content': jsonStr,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'priority': false,
        'is_deleted': false,
      });
    } catch (_) {}
  }

  // Fetch today's homework for Student ('تحضير اليوم')
  // Shows homeworks not yet completed by this student (if time expired without completion, HomeworkCard shows 'انتهى وقت الواجب')
  Future<List<Homework>> getCurrentHomework(String subjectId) async {
    final Map<String, Homework> merged = {};
    final studentCompletedIds = await getStudentCompletedHomeworkIds();
    final resetTs = await _getSchoolResetTimestamp();

    try {
      final res = await _supabase
          .from('homework')
          .select()
          .eq('subject_id', subjectId)
          .eq('is_current', true)
          .eq('is_deleted', false);
      for (final e in (res as List)) {
        final hw = Homework.fromJson(e as Map<String, dynamic>);
        if (!studentCompletedIds.contains(hw.id) &&
            (resetTs == null || !hw.createdAt.toUtc().isBefore(resetTs))) {
          merged[hw.id] = hw;
        }
      }
    } catch (_) {}

    final fallback = await _getFallbackHomeworkForSubject(subjectId);
    for (final hw in fallback) {
      if (hw.isCurrent &&
          !hw.isDeleted &&
          !studentCompletedIds.contains(hw.id) &&
          (resetTs == null || !hw.createdAt.toUtc().isBefore(resetTs))) {
        merged[hw.id] = hw;
      }
    }

    final list = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // Get active homework for a subject with safe fallback
  Stream<List<Homework>> watchCurrentHomework(String subjectId) async* {
    yield await getCurrentHomework(subjectId);
  }

  // Fetch completed & expired homework for Student ('مكتمل')
  Future<List<Homework>> getHomeworkArchive(String subjectId) async {
    final Map<String, Homework> merged = {};
    final studentCompletedIds = await getStudentCompletedHomeworkIds();
    final resetTs = await _getSchoolResetTimestamp();

    try {
      final res = await _supabase
          .from('homework')
          .select()
          .eq('subject_id', subjectId)
          .eq('is_deleted', false)
          .order('created_at', ascending: false);
      for (final e in (res as List)) {
        final hw = Homework.fromJson(e as Map<String, dynamic>);
        if ((resetTs == null || !hw.createdAt.toUtc().isBefore(resetTs)) &&
            (!hw.isCurrent || hw.isExpired || studentCompletedIds.contains(hw.id))) {
          merged[hw.id] = hw;
        }
      }
    } catch (_) {}

    final fallback = await _getFallbackHomeworkForSubject(subjectId);
    for (final hw in fallback) {
      if (!hw.isDeleted &&
          (resetTs == null || !hw.createdAt.toUtc().isBefore(resetTs)) &&
          (!hw.isCurrent || hw.isExpired || studentCompletedIds.contains(hw.id))) {
        merged[hw.id] = hw;
      }
    }

    final list = merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // Get homework archive with safe fallback
  Stream<List<Homework>> watchHomeworkArchive(String subjectId) async* {
    yield await getHomeworkArchive(subjectId);
  }

  // Add homework (Teacher)
  Future<void> addHomework(Homework homework) async {
    try {
      await _supabase.from('homework').insert(homework.toJson());
      return;
    } catch (e) {
      if (e.toString().contains('deadline') || e.toString().contains('PGRST204')) {
        try {
          // Fallback if 'deadline' column is not in DB table
          final data = homework.toJson()..remove('deadline');
          if (homework.deadline != null) {
            final fullDeadlineStr = ArabicDayHelper.formatFullDayDateTime(homework.deadline!);
            data['description'] = '${homework.description}\n\n📅 موعد التسليم: $fullDeadlineStr';
          }
          await _supabase.from('homework').insert(data);
          return;
        } catch (innerError) {
          debugPrint('[HomeworkService] Fallback homework insert notice: $innerError');
        }
      }
    }

    // Fallback for custom subjects not in 'subjects' table (FK 23503) or RLS
    final existing = await _getFallbackHomeworkForSubject(homework.subjectId);
    existing.add(homework);
    await _saveFallbackHomeworkForSubject(homework.subjectId, existing);
  }

  // Mark homework as completed locally for THIS student only (does NOT mark completed for Teacher or other students)
  Future<void> archiveHomework(String id, {String? subjectId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final schoolId = AppConstants.sanitizeSchoolId(prefs.getString(AppConstants.keySchoolCode));
      final completed = await getStudentCompletedHomeworkIds(schoolId);
      completed.add(id);
      await prefs.setStringList('${_archivedHomeworkIdsKey}_$schoolId', completed.toList());
    } catch (_) {}
  }

  // Reset all homework, archives, and announcements for a school (Start New Academic Year)
  Future<void> resetSchoolAcademicYear(String schoolId) async {
    final cleanSchoolId = AppConstants.sanitizeSchoolId(schoolId);
    final nowUtc = DateTime.now().toUtc();
    final schoolSubjectIds = await _getSchoolSubjectIds(cleanSchoolId);

    // 1. Save reset timestamp locally and in cloud so any older homework/announcements are immediately hidden
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('reset_year_ts_$cleanSchoolId', nowUtc.toIso8601String());
      await prefs.remove('${_archivedHomeworkIdsKey}_$cleanSchoolId');
      if (cleanSchoolId == AppConstants.defaultSchoolId) {
        await prefs.remove(_archivedHomeworkIdsKey);
      }
      for (final subId in schoolSubjectIds) {
        await prefs.remove('$_localHomeworkKeyPrefix$subId');
      }
    } catch (_) {}

    try {
      await _supabase.from('announcements').insert({
        'id': const Uuid().v4(),
        'school_id': cleanSchoolId,
        'title': '$_sysResetYearPrefix$cleanSchoolId',
        'content': nowUtc.toIso8601String(),
        'created_at': nowUtc.toIso8601String(),
        'priority': false,
        'is_deleted': false,
      });
    } catch (_) {}

    // 2. Also attempt to soft-delete / delete rows in DB if permitted by RLS
    if (schoolSubjectIds.isNotEmpty) {
      try {
        await _supabase
            .from('homework')
            .update({'is_deleted': true})
            .inFilter('subject_id', schoolSubjectIds.toList());
      } catch (_) {}
      try {
        await _supabase
            .from('homework')
            .delete()
            .inFilter('subject_id', schoolSubjectIds.toList());
      } catch (_) {}
    }
  }

  // Delete homework (Soft delete)
  Future<void> deleteHomework(String id) async {
    try {
      await _supabase.from('homework').update({'is_deleted': true}).eq('id', id);
    } catch (e) {
      debugPrint('[HomeworkService] deleteHomework notice: $e');
    }
  }
}