import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class LocalStorageService {
  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  // School Code (UUID)
  Future<void> saveSchoolCode(String code) async {
    await _prefs.setString(AppConstants.keySchoolCode, code);
  }

  String? getSchoolCode() {
    return _prefs.getString(AppConstants.keySchoolCode);
  }

  // School Name (e.g. مدرسة الفراهيدي الابتدائية)
  Future<void> saveSchoolName(String name) async {
    await _prefs.setString(AppConstants.keySchoolName, name);
  }

  String? getSchoolName() {
    return _prefs.getString(AppConstants.keySchoolName);
  }

  // School Short Code (e.g. SCH-1)
  Future<void> saveSchoolShortCode(String shortCode) async {
    await _prefs.setString(AppConstants.keySchoolShortCode, shortCode);
  }

  String? getSchoolShortCode() {
    return _prefs.getString(AppConstants.keySchoolShortCode);
  }

  // Student Name
  Future<void> saveStudentName(String name) async {
    await _prefs.setString(AppConstants.keyStudentName, name);
  }

  String? getStudentName() {
    return _prefs.getString(AppConstants.keyStudentName);
  }

  // Selected Grade
  Future<void> saveSelectedGrade(String gradeId) async {
    await _prefs.setString(AppConstants.keySelectedGrade, gradeId);
  }

  String? getSelectedGrade() {
    return _prefs.getString(AppConstants.keySelectedGrade);
  }

  // Selected Grade Name (e.g. الصف الأول الابتدائي)
  Future<void> saveSelectedGradeName(String gradeName) async {
    await _prefs.setString('selected_grade_name', gradeName);
  }

  String? getSelectedGradeName() {
    return _prefs.getString('selected_grade_name');
  }

  // Clear student grade selection when logging in as teacher
  Future<void> clearStudentGrade() async {
    await _prefs.remove(AppConstants.keySelectedGrade);
    await _prefs.remove('selected_grade_name');
  }

  // Clear active user session (used on Teacher or Student logout so it never drops into Student mode)
  Future<void> clearSession() async {
    await _prefs.remove(AppConstants.keySchoolCode);
    await _prefs.remove(AppConstants.keySchoolName);
    await _prefs.remove(AppConstants.keySchoolShortCode);
    await _prefs.remove(AppConstants.keySelectedGrade);
    await _prefs.remove('selected_grade_name');
    await _prefs.remove(AppConstants.keyStudentName);
  }

  // Clear all for testing or reset
  Future<void> clearAll() async {
    await clearSession();
  }
}
