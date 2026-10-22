import 'package:flutter/material.dart';
import '../../core/api/api.dart';
import '../../core/utils/feedback.dart';
import '../admin/admin_screen.dart';
import '../management/crud_screen.dart';
import '../alerts/events_screen.dart';
import '../monitoring/motion_screen.dart';
import '../location/location_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onSignedOut});
  final VoidCallback onSignedOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int? deviceCount;
  int? alertCount;
  int? userCount;
  bool loading = false;

  bool get isAdmin => Api.instance.role == 'Admin';
  bool get isOwner => Api.instance.role == 'Owner';
  bool get canManage => isAdmin || isOwner;

  String get roleLabel => switch (Api.instance.role) {
    'Admin' => 'Quản trị viên',
    'Owner' => 'Khách hàng / chủ sở hữu',
    'Member' => 'Nhân viên / thành viên',
    _ => Api.instance.role ?? 'Người dùng',
  };

  @override
  void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      if (isAdmin) {
        final response = await Api.instance.request('GET', '/api/admin/summary');
        final data = Map<String, dynamic>.from(response as Map);
        if (mounted) setState(() {
          userCount = int.tryParse('${data['userCount']}');
          deviceCount = int.tryParse('${data['deviceCount']}');
          alertCount = int.tryParse('${data['eventCount']}');
        });
      } else {
        final devices = await Api.instance.list('devices');
        final events = await Api.instance.list('events');
        if (mounted) setState(() {
          deviceCount = devices.length;
          alertCount = events.where((e) => e['acknowledgedAt'] == null).length;
        });
      }
    } catch (_) {
      // Let users access screens and troubleshoot API even when counts fail to load.
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) refresh();
  }

  Future<void> signOut() async {
    try {
      await Api.instance.logout();
      widget.onSignedOut();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Widget feature({required IconData icon, required String title,
      required String subtitle, required Widget screen, Color? color}) {
    return Card(child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: CircleAvatar(
        backgroundColor: (color ?? const Color(0xFF0A9189)).withValues(alpha: .12),
        child: Icon(icon, color: color ?? const Color(0xFF0A9189)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => open(screen),
    ));
  }

  Widget section(String title, List<Widget> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 22),
      Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...items,
    ],
  );

  Widget metric(String value, String label, IconData icon) => Expanded(child: Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Icon(icon, color: const Color(0xFF0A9189)), const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12))],
    )),
  ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartGuard'),
        actions: [
          IconButton(tooltip: 'Tài khoản & bảo mật', icon: const Icon(Icons.manage_accounts_outlined),
            onPressed: () => open(const SettingsScreen())),
          IconButton(tooltip: 'Đăng xuất', icon: const Icon(Icons.logout), onPressed: signOut),
        ],
      ),
      body: RefreshIndicator(onRefresh: refresh, child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF10233F),
              borderRadius: BorderRadius.circular(22)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.shield_rounded, color: Color(0xFF8DDFD4), size: 48),
              const SizedBox(height: 14),
              Text('Xin chào, ${Api.instance.username ?? 'bạn'}',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(roleLabel, style: const TextStyle(color: Color(0xFFD5E9F2))),
              const SizedBox(height: 16),
              Text(isAdmin ? 'Quản lý người dùng và hệ thống bảo vệ.'
                : isOwner ? 'Điện thoại của bạn có thể giám sát tài sản và báo động khi bị di chuyển.'
                : 'Theo dõi thiết bị và xử lý thông tin theo quyền được cấp.',
                style: const TextStyle(color: Colors.white70)),
            ]),
          ),
          if (loading) const LinearProgressIndicator(),
          const SizedBox(height: 14),
          Row(children: [
            metric(deviceCount?.toString() ?? '—', 'Thiết bị', Icons.smartphone),
            metric(alertCount?.toString() ?? '—', isAdmin ? 'Sự kiện' : 'Cảnh báo mới', Icons.notifications_active),
            if (isAdmin) metric(userCount?.toString() ?? '—', 'Người dùng', Icons.people),
          ]),
          if (canManage) section('Chống trộm', [
            feature(icon: Icons.sensors, title: 'Bật bảo vệ / đo chuyển động',
              subtitle: 'Đo rung thật, ngưỡng thích ứng, tạo cảnh báo API',
              screen: const MotionScreen(), color: const Color(0xFFCF5A25)),
          ]),
          section('Theo dõi an toàn', [
            feature(icon: Icons.location_on_outlined, title: 'Vị trí GPS',
              subtitle: 'Xem vị trí và chia sẻ thủ công theo quyền', screen: const LocationScreen()),
            feature(icon: Icons.notifications_none, title: 'Lịch sử cảnh báo',
              subtitle: 'Xem các sự kiện đã lưu, xác nhận khi được phép', screen: const EventsScreen()),
          ]),
          section('Quản lý tài sản', [
            feature(icon: Icons.smartphone, title: 'Thiết bị bảo vệ',
              subtitle: canManage ? 'Thêm, xem, sửa, xóa thiết bị' : 'Xem thiết bị được chia sẻ',
              screen: const CrudScreen(kind: 'devices')),
            if (canManage) ...[
              feature(icon: Icons.grid_view_rounded, title: 'Khu vực bảo vệ',
                subtitle: 'CRUD khu vực giám sát', screen: const CrudScreen(kind: 'zones')),
              feature(icon: Icons.tune, title: 'Cấu hình cảnh báo',
                subtitle: 'CRUD mức nhạy, âm lượng và độ trễ', screen: const CrudScreen(kind: 'configs')),
              feature(icon: Icons.group_outlined, title: 'Thành viên được chia sẻ',
                subtitle: 'CRUD quyền xem và xác nhận cảnh báo', screen: const CrudScreen(kind: 'members')),
            ],
          ]),
          if (isAdmin) section('Quản trị hệ thống', [
            feature(icon: Icons.admin_panel_settings_outlined, title: 'Quản lý người dùng',
              subtitle: 'Xem người dùng và đổi quyền Owner / Member',
              screen: const AdminScreen()),
          ]),
          section('Tài khoản & tiện ích', [
            feature(icon: Icons.face, title: 'Đăng nhập bằng khuôn mặt',
              subtitle: 'Bật khóa phiên bằng sinh trắc học trên máy hỗ trợ',
              screen: const SettingsScreen()),
          ]),
          const SizedBox(height: 14),
          const Text('Lưu ý: cảm biến chỉ theo dõi khi màn hình giám sát đang mở. '
            'OTP gửi Gmail và quyền API phụ thuộc cấu hình backend.',
            style: TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      )),
    );
  }
}
