import 'dart:js_interop';

@JS('requestWebNotificationPermission')
external JSPromise<JSBoolean> _requestWebNotificationPermission();

@JS('setWebUserTags')
external JSPromise<JSAny?> _setWebUserTags(JSString schoolCode, JSString? classId);

@JS('removeWebUserTags')
external JSPromise<JSAny?> _removeWebUserTags();

Future<bool> requestWebNotificationPermission() async {
  try {
    final result = await _requestWebNotificationPermission().toDart;
    return result.toDart;
  } catch (e) {
    return false;
  }
}

Future<void> setWebUserTags(String schoolCode, {String? classId}) async {
  try {
    await _setWebUserTags(schoolCode.toJS, classId?.toJS).toDart;
  } catch (_) {}
}

Future<void> removeWebUserTags() async {
  try {
    await _removeWebUserTags().toDart;
  } catch (_) {}
}
