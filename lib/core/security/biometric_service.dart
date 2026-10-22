import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../api/api.dart';

/// Local screen unlock for an EXISTING verified JWT session.
/// Not a replacement for server login, email OTP, or Google Sign-In.
/// Android BiometricPrompt chooses the available enrolled modality.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _enabledKey = 'face_unlock_enabled';
  static const String _userKey = 'face_unlock_user';

  Future<bool> isEnabled() async {
    final user = await _storage.read(key: _userKey);
    return user != null && user == Api.instance.username &&
        (await _storage.read(key: _enabledKey)) == 'true';
  }

  Future<bool> hasEnrolledFace() async {
    if (!await _auth.canCheckBiometrics) return false;
    final enrolled = await _auth.getAvailableBiometrics();
    return enrolled.contains(BiometricType.face);
  }

  Future<bool> unlock() async {
    if (!await hasEnrolledFace()) return false;
    return _auth.authenticate(
      localizedReason: 'Xác minh sinh trắc học để mở SmartGuard',
      options: const AuthenticationOptions(
        biometricOnly: true,
      ),
    );
  }

  Future<void> enable() async {
    if (!await hasEnrolledFace()) {
      throw StateError('Thiết bị chưa báo có khuôn mặt đã đăng ký và hỗ trợ.');
    }
    final authenticated = await unlock();
    if (!authenticated) throw StateError('Xác minh sinh trắc học chưa thành công.');
    final user = Api.instance.username;
    if (user == null || user.isEmpty) {
      throw StateError('Bạn cần đăng nhập bằng OTP trước khi bật khuôn mặt.');
    }
    await _storage.write(key: _userKey, value: user);
    await _storage.write(key: _enabledKey, value: 'true');
  }

  Future<void> disable() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _userKey);
  }
}
