import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api.dart';
import '../../core/utils/feedback.dart';

/// Location is sent ONLY after a visible user action with runtime permission.
class LocationScreen extends StatefulWidget {
  const LocationScreen({super.key});
  @override State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {
  List<Map<String, dynamic>> devices = [];
  List<Map<String, dynamic>> locations = [];
  String? selectedId;
  bool loading = false;
  bool sharing = false;
  @override void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    setState(() => loading = true);
    try {
      final d = await Api.instance.list('devices');
      final l = await Api.instance.list('locations');
      if (mounted) setState(() {
        devices = d; locations = l;
        if (!d.any((x) => x['id']?.toString() == selectedId)) selectedId = d.isEmpty ? null : d.first['id'].toString();
      });
    } catch (e) { if (mounted) showError(context, e); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> shareNow() async {
    if (selectedId == null) return;
    final accepted = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Cho phép chia sẻ vị trí?'),
      content: const Text('Tọa độ hiện tại của điện thoại sẽ được lưu vào API và '
        'hiển thị cho chủ sở hữu và thành viên có quyền xem thiết bị. '
        'Chỉ gửi một lần khi bạn xác nhận.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Đồng ý gửi'))]));
    if (accepted != true) return;
    setState(() => sharing = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw ApiException('Hãy bật dịch vụ vị trí/GPS của điện thoại.', 0);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw ApiException('Chưa được cấp quyền vị trí.', 0);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20)));
      await Api.instance.request('POST', '/api/locations/devices/$selectedId',
        {'latitude': position.latitude, 'longitude': position.longitude,
          'accuracyMeters': position.accuracy});
      if (mounted) { showNotice(context, 'Đã cập nhật vị trí cho thiết bị.'); await refresh(); }
    } catch (e) { if (mounted) showError(context, e); }
    finally { if (mounted) setState(() => sharing = false); }
  }

  Future<void> openMap(Map<String, dynamic> position) async {
    final lat = position['latitude']; final lon = position['longitude'];
    final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat%2C$lon');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      showNotice(context, 'Không mở được trình duyệt bản đồ.');
    }
  }

  @override Widget build(BuildContext context) {
    final canShare = Api.instance.role != 'Member';
    return Scaffold(
      appBar: AppBar(title: const Text('Chia sẻ vị trí GPS'),
        actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))]),
      body: loading ? const Center(child: CircularProgressIndicator()) : ListView(
        padding: const EdgeInsets.all(16), children: [
          const Card(child: Padding(padding: EdgeInsets.all(14), child: Text(
            'Bản này chia sẻ vị trí thủ công: mỗi lần bấm là một lần gửi. '
            'Không theo dõi nền và không thu GPS liên tục.'))),
          if (canShare) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(key: ValueKey(selectedId),
              initialValue: selectedId, decoration: const InputDecoration(labelText: 'Thiết bị cập nhật vị trí'),
              items: devices.map((d) => DropdownMenuItem<String>(value: d['id'].toString(),
                child: Text(d['name'].toString()))).toList(),
              onChanged: (v) => setState(() => selectedId = v)),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: selectedId == null || sharing ? null : shareNow,
              icon: const Icon(Icons.my_location),
              label: Text(sharing ? 'Đang lấy GPS...' : 'Gửi vị trí hiện tại')),
          ],
          const SizedBox(height: 24),
          Text('Vị trí gần nhất được chia sẻ', style: Theme.of(context).textTheme.titleMedium),
          if (locations.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('Chưa có vị trí nào được chia sẻ.')),
          ...locations.map((pos) => Card(child: ListTile(
            leading: const Icon(Icons.location_pin, color: Colors.red),
            title: Text(pos['deviceName']?.toString() ?? 'Thiết bị'),
            subtitle: Text('${pos['latitude']}, ${pos['longitude']}\n${pos['updatedAt']}'),
            isThreeLine: true,
            trailing: IconButton(onPressed: () => openMap(pos),
              tooltip: 'Mở Google Maps', icon: const Icon(Icons.map_outlined)),
          ))),
        ]),
    );
  }
}
