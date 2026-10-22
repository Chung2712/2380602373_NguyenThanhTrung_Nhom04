import 'package:flutter/material.dart';
import '../../core/security/biometric_service.dart';
import '../../core/utils/feedback.dart';

class BiometricLockScreen extends StatefulWidget {
  const BiometricLockScreen({super.key, required this.onUnlocked, required this.onSignOut});
  final VoidCallback onUnlocked;
  final Future<void> Function() onSignOut;

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  bool busy = false;

  Future<void> unlock() async {
    setState(() => busy = true);
    try {
      if (await BiometricService.instance.unlock()) widget.onUnlocked();
      else if (mounted) showNotice(context, 'Chưa xác minh được khuôn mặt.');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.face_retouching_natural, size: 76, color: Color(0xFF0A9189)),
          const SizedBox(height: 20),
          Text('Mở khóa SmartGuard', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text('Xác minh trên điện thoại để mở phiên đăng nhập đã lưu.',
            textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: busy ? null : unlock,
            icon: const Icon(Icons.face), label: const Text('Xác minh sinh trắc học')),
          const SizedBox(height: 12),
          TextButton(onPressed: busy ? null : widget.onSignOut,
            child: const Text('Dùng tài khoản và OTP để đăng nhập lại')),
          if (busy) const CircularProgressIndicator(),
        ])),
    ))),
  );
}
