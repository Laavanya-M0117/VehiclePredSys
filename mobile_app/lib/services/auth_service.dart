import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'vehicle_triage_jwt_token';
  static const String _userKey = 'vehicle_triage_user_email';

  Future<void> saveSession(String token, String email) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userKey, value: email);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  Future<String?> getUserEmail() async {
    return await _storage.read(key: _userKey);
  }

  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
