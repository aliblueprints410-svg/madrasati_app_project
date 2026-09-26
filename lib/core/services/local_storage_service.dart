import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class LocalStorageService {
  final SharedPreferences _prefs;

  LocalStorageService(this._prefs);

  // School Code
  Future<void> saveSchoolCode(String code) async {
    await _prefs.setString(AppConstants.keySchoolCode, code);
  }

  String? getSchoolCode() {
    return _prefs.getString(AppConstants.keySchoolCode);
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

  // Clear all for testing or reset
  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
