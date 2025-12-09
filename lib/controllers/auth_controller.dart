import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../services/exceptions.dart';
import '../services/notification_service.dart';

class AuthController extends ChangeNotifier {
  AuthController({required SharedPreferences prefs}) : _prefs = prefs {
    _token = _prefs.getString(_tokenKey);
    _phone = _prefs.getString(_phoneKey);
    _userId = _prefs.getInt(_userIdKey);
  }

  static const _tokenKey = 'auth.accessToken';
  static const _phoneKey = 'auth.phone';
  static const _userIdKey = 'auth.userId';

  final SharedPreferences _prefs;
  ApiClient? _apiClient;
  NotificationService? _notificationService;

  String? _token;
  String? _phone;
  int? _userId;
  String? _otpToken;
  String? _deviceToken;
  String _devicePlatform = 'android';
  String? _lastMessage;
  bool _isSubmitting = false;
  bool _isCheckingSession = false;
  bool _isSessionChecked = false;

  String? get token => _token;
  String? get phone => _phone;
  int? get userId => _userId;
  bool get isAuthenticated => _token != null;
  bool get isSubmitting => _isSubmitting;
  String? get lastMessage => _lastMessage;
  bool get isCheckingSession => _isCheckingSession;
  bool get isSessionChecked => _isSessionChecked;

  void attachApiClient(ApiClient client) {
    _apiClient = client;
  }

  void attachNotificationService(NotificationService service) {
    _notificationService = service;
  }

  void updateDeviceToken(String? token) {
    _deviceToken = token;
    notifyListeners();
  }

  void updateDevicePlatform(String? platform) {
    if (platform == null || platform.isEmpty) return;
    _devicePlatform = platform;
    notifyListeners();
  }

  Future<bool> checkSession() async {
    _ensureClient();
    if (_token == null) {
      _isSessionChecked = true;
      notifyListeners();
      return false;
    }
    if (_isCheckingSession) return _token != null;
    _isCheckingSession = true;
    notifyListeners();
    try {
      final response = await _apiClient!.getJson('/auth/me');
      _userId = (response['user_id'] as num?)?.toInt() ?? _userId;
      _phone = response['phone']?.toString() ?? _phone;
      if (_userId != null) {
        await _prefs.setInt(_userIdKey, _userId!);
      }
      if (_phone != null) {
        await _prefs.setString(_phoneKey, _phone!);
      }
      notifyListeners();
      return true;
    } catch (_) {
      await logout();
      return false;
    } finally {
      _isCheckingSession = false;
      _isSessionChecked = true;
      notifyListeners();
    }
  }

  Future<String> requestOtp(String phone) async {
    _ensureClient();
    _toggleSubmitting(true);
    try {
      final response = await _apiClient!.postJson(
        '/auth/request-otp',
        body: {'phone': phone},
        authRequired: false,
      );
      _otpToken = response['otp_token'] as String?;
      _lastMessage = response['detail'] as String?;
      _phone = phone;
      notifyListeners();
      return _lastMessage ?? 'کد ارسال شد.';
    } finally {
      _toggleSubmitting(false);
    }
  }

  Future<void> verifyOtp(String code) async {
    _ensureClient();
    if (_otpToken == null || _phone == null) {
      throw const ApiException('ابتدا کد تایید را دریافت کنید.');
    }

    _toggleSubmitting(true);
    try {
      final response = await _apiClient!.postJson(
        '/auth/verify-otp',
        body: {
          'phone': _phone,
          'code': code,
          'device_token': _deviceToken,
          'device_platform': _devicePlatform,
        },
        authRequired: false,
        extraHeaders: {'Authorization': 'Bearer $_otpToken'},
      );

      final access = response['token'] as String?;
      if (access == null) {
        throw const ApiException('توکن دسترسی نامعتبر است.');
      }

      _token = access;
      _userId = (response['user_id'] as num?)?.toInt();
      _phone = response['phone'] as String? ?? _phone;
      _otpToken = null;
      await _prefs.setString(_tokenKey, _token!);
      if (_phone != null) {
        await _prefs.setString(_phoneKey, _phone!);
      }
      if (_userId != null) {
        await _prefs.setInt(_userIdKey, _userId!);
      }
      notifyListeners();
      if (_userId != null) {
        await _notificationService?.subscribeUserTopic(_userId!);
      }
    } finally {
      _toggleSubmitting(false);
    }
  }

  Future<void> logout() async {
    if (_userId != null) {
      await _notificationService?.unsubscribeUserTopic(_userId!);
    }
    _token = null;
    _userId = null;
    _otpToken = null;
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_phoneKey);
    await _prefs.remove(_userIdKey);
    _otpToken = null;
    notifyListeners();
  }

  void _ensureClient() {
    if (_apiClient == null) {
      throw const ApiException('ApiClient متصل نشده است.');
    }
  }

  void _toggleSubmitting(bool value) {
    if (_isSubmitting == value) return;
    _isSubmitting = value;
    notifyListeners();
  }
}
