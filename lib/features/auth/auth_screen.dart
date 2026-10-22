import 'package:flutter/material.dart';
import '../../core/api/api.dart';
import '../../core/utils/feedback.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onSignedIn});
  final VoidCallback onSignedIn;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _otp = TextEditingController();
  final _url = TextEditingController(text: Api.instance.baseUrl);
  final _form = GlobalKey<FormState>();
  bool register = false;
  bool loading = false;
  String? challengeId;
  String? developmentOtp;
  String? purpose;

  @override
  void dispose() {
    for (final c in [_username, _email, _password, _otp, _url]) { c.dispose(); }
    super.dispose();
  }

  Future<void> submit() async {
    if (challengeId == null && !_form.currentState!.validate()) return;
    setState(() => loading = true);
    try {
      if (challengeId == null) {
        final result = Map<String, dynamic>.from(await Api.instance.request(
          'POST', register ? '/api/auth/register' : '/api/auth/login',
          register
              ? {'username': _username.text.trim(), 'email': _email.text.trim(), 'password': _password.text}
              : {'username': _username.text.trim(), 'password': _password.text},
        ) as Map);
        setState(() {
          challengeId = result['challengeId']?.toString();
          developmentOtp = result['developmentOtp']?.toString();
          purpose = register ? 'verify-email' : 'verify-login';
        });
      } else {
        if (_otp.text.trim().length != 6) {
          throw ApiException('Mã OTP phải gồm 6 chữ số.', 0);
        }
        final result = await Api.instance.request('POST', '/api/auth/$purpose',
          {'challengeId': challengeId, 'code': _otp.text.trim()});
        if (register) {
          setState(() { challengeId = null; developmentOtp = null; register = false; _otp.clear(); });
          if (mounted) showNotice(context, 'Xác minh email thành công. Hãy đăng nhập.');
        } else {
          await Api.instance.saveSession(Map<String, dynamic>.from(result as Map));
          widget.onSignedIn();
        }
      }
    } catch (e) { if (mounted) showError(context, e); }
    finally { if (mounted) setState(() => loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const CircleAvatar(radius: 32, backgroundColor: Color(0xFF10233F),
              child: Icon(Icons.shield_outlined, color: Colors.white, size: 36)),
            const SizedBox(height: 16),
            Text('SmartGuard', textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const Text('Biến điện thoại thành thiết bị chống trộm', textAlign: TextAlign.center),
            const SizedBox(height: 32),
            Text(challengeId == null
                ? (register ? 'Đăng ký tài khoản' : 'Đăng nhập')
                : 'Xác thực OTP', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (challengeId == null) ...[
              TextFormField(controller: _username, decoration: const InputDecoration(
                labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => v == null || v.trim().length < 3 ? 'Ít nhất 3 ký tự' : null),
              const SizedBox(height: 12),
              if (register) ...[
                TextFormField(controller: _email, keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => v == null || !v.contains('@') ? 'Email không hợp lệ' : null),
                const SizedBox(height: 12),
              ],
              TextFormField(controller: _password, obscureText: true,
                decoration: const InputDecoration(labelText: 'Mật khẩu', prefixIcon: Icon(Icons.lock_outline)),
                validator: (v) => v == null || v.length < 8 ? 'Ít nhất 8 ký tự' : null),
              const SizedBox(height: 12),
              ExpansionTile(title: const Text('Cấu hình Web API'), children: [
                TextField(controller: _url, decoration: const InputDecoration(labelText: 'URL Web API')),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: loading ? null : () async {
                  try {
                    await Api.instance.setBaseUrl(_url.text);
                    await Api.instance.request('GET', '/api/health');
                    if (context.mounted) showNotice(context, 'Kết nối API thành công.');
                  } catch (e) { if (context.mounted) showError(context, e); }
                }, icon: const Icon(Icons.wifi_find), label: const Text('Kiểm tra kết nối')),
              ]),
            ] else ...[
              const Text('Nhập mã OTP 6 chữ số gửi đến email của bạn.'),
              const SizedBox(height: 12),
              TextField(controller: _otp, autofocus: true, keyboardType: TextInputType.number,
                maxLength: 6, decoration: const InputDecoration(labelText: 'Mã OTP')),
              if (developmentOtp != null && developmentOtp!.isNotEmpty)
                Card(color: Colors.amber.shade100, child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('CHỈ DEMO DEVELOPMENT – OTP: $developmentOtp\n'
                      'OTP Gmail chỉ được gửi khi backend đã cấu hình dịch vụ email.'))),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(onPressed: loading ? null : submit,
              icon: loading ? const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward),
              label: Text(challengeId != null ? 'Xác nhận OTP' : (register ? 'Đăng ký' : 'Đăng nhập'))),
            TextButton(onPressed: loading ? null : () => setState(() {
              if (challengeId != null) { challengeId = null; developmentOtp = null; }
              else { register = !register; }
              _otp.clear();
            }), child: Text(challengeId != null ? 'Quay lại' :
              register ? 'Đã có tài khoản? Đăng nhập' : 'Chưa có tài khoản? Đăng ký')),
          ]),
        )),
      ))),
    );
  }
}
