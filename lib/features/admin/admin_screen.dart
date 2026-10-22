import 'package:flutter/material.dart';
import '../../core/api/api.dart';
import '../../core/utils/feedback.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> users = [];
  bool loading = true;
  @override void initState() { super.initState(); refresh(); }
  Future<void> refresh() async {
    setState(() => loading = true);
    try { final data = await Api.instance.list('admin/users');
      if (mounted) setState(() => users = data);
    } catch (e) { if (mounted) showError(context, e); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> changeRole(Map<String, dynamic> user, String role) async {
    try {
      await Api.instance.request('PUT', '/api/admin/users/${user['id']}/role', {'role': role});
      if (mounted) { showNotice(context, 'Đã thay đổi vai trò'); refresh(); }
    } catch (e) { if (mounted) showError(context, e); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Quản trị người dùng'), actions: [IconButton(
      onPressed: refresh, icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator()) :
      ListView.builder(itemCount: users.length, itemBuilder: (context, i) {
        final user = users[i];
        return Card(child: ListTile(
          title: Text('${user['username']} (${user['role']})'),
          subtitle: Text('${user['email']} • ${user['emailVerified'] == true ? 'Đã xác minh' : 'Chưa xác minh'}'),
          trailing: user['role'] == 'Admin' ? const Icon(Icons.verified_user) : PopupMenuButton<String>(
            onSelected: (role) => changeRole(user, role),
            itemBuilder: (_) => [const PopupMenuItem(value: 'Owner', child: Text('Chủ sở hữu')),
              const PopupMenuItem(value: 'Member', child: Text('Thành viên'))]),
        ));
      }),
  );
}
