import 'package:flutter/material.dart';
import '../../core/api/api.dart';
import '../../core/security/biometric_service.dart';
import '../../core/utils/feedback.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool loading = true;
  bool faceEnabled = false;
  bool faceAvailable = false;

  @override
  void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final enabled = await BiometricService.instance.isEnabled();
      final available = await BiometricService.instance.hasEnrolledFace();
      if (mounted) setState(() { faceEnabled = enabled; faceAvailable = available; });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> updateFace(bool value) async {
    setState(() => loading = true);
    try {
      if (value) { await BiometricService.instance.enable(); }
      else { await BiometricService.instance.disable(); }
      if (mounted) {
        setState(() => faceEnabled = value);
        showNotice(context, value ? 'Đã bật mở khóa sinh trắc học.' : 'Đã tắt mở khóa sinh trắc học.');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tài khoản & bảo mật')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      Card(child: Column(children: [
        ListTile(leading: const Icon(Icons.person_outline), title: Text(Api.instance.username ?? 'Người dùng'),
          subtitle: Text('Vai trò API: ${Api.instance.role ?? 'Không rõ'}')),
        const Divider(height: 1),
        ListTile(leading: const Icon(Icons.link), title: const Text('Địa chỉ Web API'),
          subtitle: Text(Api.instance.baseUrl)),
      ])),
      const SizedBox(height: 18),
      Text('Xác thực khuôn mặt', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Card(child: Column(children: [
        SwitchListTile(
          secondary: const Icon(Icons.face_rounded),
          title: const Text('Mở khóa bằng khuôn mặt'),
          subtitle: Text(faceAvailable
            ? 'Yêu cầu xác minh sinh trắc học khi mở lại phiên đã lưu.'
            : 'Điện thoại chưa báo có khuôn mặt đã đăng ký hoặc không hỗ trợ qua Android.'),
          value: faceEnabled,
          onChanged: loading || (!faceAvailable && !faceEnabled) ? null : updateFace,
        ),
        const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text('Đây là mở khóa phiên JWT đã đăng nhập bằng OTP trước đó, không phải '
            'đăng nhập tài khoản mới. Android quyết định phương thức sinh trắc học khi hiện hộp thoại; '
            'một số máy có thể chọn phương thức khác. Không thay thế xác thực OTP phía server.',
            style: TextStyle(fontSize: 12))),
      ])),
      const SizedBox(height: 12),
      OutlinedButton.icon(onPressed: loading ? null : refresh,
        icon: const Icon(Icons.refresh), label: const Text('Kiểm tra khả năng khuôn mặt')),
    ]),
  );
}
