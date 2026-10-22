import 'package:flutter/material.dart';
import '../../core/api/api.dart';
import '../../core/utils/feedback.dart';

class CrudScreen extends StatefulWidget {
  const CrudScreen({super.key, required this.kind});
  final String kind; // devices / zones / configs / members
  @override
  State<CrudScreen> createState() => _CrudScreenState();
}

class _CrudScreenState extends State<CrudScreen> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _code = TextEditingController();
  final _email = TextEditingController();
  final _sensitivity = TextEditingController(text: '5');
  final _volume = TextEditingController(text: '80');
  final _delay = TextEditingController(text: '0');
  List<Map<String, dynamic>> items = [];
  List<Map<String, dynamic>> zones = [];
  List<Map<String, dynamic>> configs = [];
  List<Map<String, dynamic>> devices = [];
  String? zoneId;
  String? configId;
  String? selectedDeviceId;
  bool isArmed = false;
  bool canAcknowledge = false;
  bool busy = true;
  String? error;

  String get title => switch (widget.kind) {
    'devices' => 'Thiết bị chống trộm',
    'zones' => 'Khu vực giám sát',
    'configs' => 'Cấu hình cảnh báo',
    _ => 'Thành viên được chia sẻ',
  };
  bool get owner => Api.instance.role != 'Member';

  @override
  void initState() { super.initState(); load(); }

  @override
  void dispose() {
    for (final c in [_name, _description, _code, _email, _sensitivity, _volume, _delay]) { c.dispose(); }
    super.dispose();
  }

  Future<void> load() async {
    setState(() { busy = true; error = null; });
    try {
      final values = await Api.instance.list(widget.kind);
      if (widget.kind == 'devices') {
        zones = owner ? await Api.instance.list('zones') : [];
        configs = owner ? await Api.instance.list('configs') : [];
      } else if (widget.kind == 'members') {
        devices = await Api.instance.list('devices');
      }
      if (mounted) setState(() => items = values);
    } catch (e) { if (mounted) setState(() => error = humanError(e)); }
    finally { if (mounted) setState(() => busy = false); }
  }

  String detail(Map<String, dynamic> row) => switch (widget.kind) {
    'devices' => '${row['deviceCode']}  •  ${row['isArmed'] == true ? 'Đang bảo vệ' : 'Đã tắt'}',
    'zones' => (row['description'] ?? '').toString(),
    'configs' => 'Nhạy ${row['sensitivity']}/10 • Loa ${row['alarmVolume']}% • Trễ ${row['delaySeconds']}s',
    _ => '${row['deviceId'] == null ? 'Tất cả thiết bị' : 'Một thiết bị'} • '
         '${row['canAcknowledge'] == true ? 'Được xác nhận cảnh báo' : 'Chỉ xem'}',
  };

  String label(Map<String, dynamic> row) =>
    widget.kind == 'members' ? (row['memberEmail'] ?? '').toString() : (row['name'] ?? '').toString();

  DropdownButtonFormField<String?> dropdown(String title, String? value,
      List<Map<String, dynamic>> choices, ValueChanged<String?> changed) {
    final usable = choices.any((x) => x['id'].toString() == value) ? value : null;
    return DropdownButtonFormField<String?>(
      key: ValueKey('$title$usable'),
      initialValue: usable,
      decoration: InputDecoration(labelText: title), isExpanded: true,
      items: [const DropdownMenuItem<String?>(value: null, child: Text('Tất cả / Chưa chọn')),
        ...choices.map((x) => DropdownMenuItem<String?>(value: x['id'].toString(),
          child: Text((x['name'] ?? x['deviceCode'] ?? '').toString(), overflow: TextOverflow.ellipsis)))],
      onChanged: changed,
    );
  }

  void prepare(Map<String, dynamic>? row) {
    _name.text = row?['name']?.toString() ?? '';
    _description.text = row?['description']?.toString() ?? '';
    _code.text = row?['deviceCode']?.toString() ?? '';
    _email.text = row?['memberEmail']?.toString() ?? '';
    _sensitivity.text = row?['sensitivity']?.toString() ?? '5';
    _volume.text = row?['alarmVolume']?.toString() ?? '80';
    _delay.text = row?['delaySeconds']?.toString() ?? '0';
    zoneId = row?['zoneId']?.toString();
    configId = row?['configId']?.toString();
    selectedDeviceId = row?['deviceId']?.toString();
    isArmed = row?['isArmed'] == true;
    canAcknowledge = row?['canAcknowledge'] == true;
  }

  Future<void> edit([Map<String, dynamic>? row]) async {
    prepare(row);
    final formKey = GlobalKey<FormState>();
    bool submitting = false;
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialog) => AlertDialog(
        title: Text(row == null ? 'Thêm ${title.toLowerCase()}' : 'Sửa ${title.toLowerCase()}'),
        content: SizedBox(width: 430, child: SingleChildScrollView(child: Form(key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.kind != 'members') ...[
              TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Tên'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Bắt buộc' : null),
              const SizedBox(height: 12),
            ],
            if (widget.kind == 'zones' || widget.kind == 'devices') ...[
              TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Mô tả')),
              const SizedBox(height: 12),
            ],
            if (widget.kind == 'devices') ...[
              TextFormField(controller: _code, decoration: const InputDecoration(labelText: 'Mã thiết bị'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Bắt buộc' : null),
              const SizedBox(height: 12),
              dropdown('Khu vực', zoneId, zones, (v) => setDialog(() => zoneId = v)),
              const SizedBox(height: 12),
              dropdown('Cấu hình', configId, configs, (v) => setDialog(() => configId = v)),
              SwitchListTile(title: const Text('Bật bảo vệ'), value: isArmed,
                onChanged: (v) => setDialog(() => isArmed = v)),
            ],
            if (widget.kind == 'configs') ...[
              TextFormField(controller: _sensitivity, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Độ nhạy 1–10'),
                validator: (v) { final n = int.tryParse(v ?? ''); return n == null || n < 1 || n > 10 ? '1–10' : null; }),
              const SizedBox(height: 12),
              TextFormField(controller: _volume, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Âm lượng 0–100'),
                validator: (v) { final n = int.tryParse(v ?? ''); return n == null || n < 0 || n > 100 ? '0–100' : null; }),
              const SizedBox(height: 12),
              TextFormField(controller: _delay, keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Trễ 0–60 giây'),
                validator: (v) { final n = int.tryParse(v ?? ''); return n == null || n < 0 || n > 60 ? '0–60' : null; }),
            ],
            if (widget.kind == 'members') ...[
              TextFormField(controller: _email, enabled: row == null,
                decoration: const InputDecoration(labelText: 'Email thành viên đã đăng ký'),
                validator: (v) => row == null && (v == null || !v.contains('@')) ? 'Email không hợp lệ' : null),
              const SizedBox(height: 12),
              dropdown('Cho phép truy cập', selectedDeviceId, devices,
                (v) => setDialog(() => selectedDeviceId = v)),
              SwitchListTile(title: const Text('Được xác nhận cảnh báo'),
                value: canAcknowledge, onChanged: (v) => setDialog(() => canAcknowledge = v)),
            ],
          ]),
        ))),
        actions: [
          TextButton(onPressed: submitting ? null : () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          FilledButton(onPressed: submitting ? null : () async {
            if (!formKey.currentState!.validate()) return;
            setDialog(() => submitting = true);
            final data = switch (widget.kind) {
              'zones' => {'name': _name.text.trim(), 'description': _description.text.trim()},
              'configs' => {'name': _name.text.trim(), 'sensitivity': int.parse(_sensitivity.text),
                'alarmVolume': int.parse(_volume.text), 'delaySeconds': int.parse(_delay.text)},
              'devices' => {'name': _name.text.trim(), 'deviceCode': _code.text.trim(),
                'description': _description.text.trim(), 'zoneId': zoneId, 'configId': configId, 'isArmed': isArmed},
              _ => row == null ? {'email': _email.text.trim(), 'deviceId': selectedDeviceId,
                    'canAcknowledge': canAcknowledge}
                  : {'deviceId': selectedDeviceId, 'canAcknowledge': canAcknowledge},
            };
            try {
              await Api.instance.request(row == null ? 'POST' : 'PUT',
                '/api/${widget.kind}${row == null ? '' : '/${row['id']}'}', data);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (mounted) { showNotice(context, 'Đã lưu thành công'); load(); }
            } catch (e) {
              if (dialogContext.mounted) showError(dialogContext, e);
              if (dialogContext.mounted) setDialog(() => submitting = false);
            }
          }, child: const Text('Lưu')),
        ],
      ),
    ));
  }

  Future<void> delete(Map<String, dynamic> row) async {
    final accepted = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Xác nhận xóa'), content: Text('Xóa "${label(row)}"? Thao tác không thể hoàn tác.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa'))]));
    if (accepted != true) return;
    try {
      await Api.instance.request('DELETE', '/api/${widget.kind}/${row['id']}');
      if (mounted) { showNotice(context, 'Đã xóa'); load(); }
    } catch (e) { if (mounted) showError(context, e); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: load)]),
      floatingActionButton: owner ? FloatingActionButton.extended(
        onPressed: () => edit(), icon: const Icon(Icons.add), label: const Text('Thêm mới')) : null,
      body: busy ? const Center(child: CircularProgressIndicator())
          : error != null ? Center(child: Padding(padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [Text(error!),
                TextButton(onPressed: load, child: const Text('Thử lại'))])))
          : items.isEmpty ? const Center(child: Text('Chưa có dữ liệu. Hãy thêm mới.'))
          : RefreshIndicator(onRefresh: load, child: ListView.builder(
              padding: const EdgeInsets.all(12), itemCount: items.length,
              itemBuilder: (context, index) {
                final row = items[index];
                return Card(child: ListTile(
                  leading: CircleAvatar(child: Icon(switch (widget.kind) {
                    'devices' => Icons.smartphone, 'zones' => Icons.room_preferences,
                    'configs' => Icons.tune, _ => Icons.people,
                  })),
                  title: Text(label(row), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(detail(row)),
                  trailing: owner ? PopupMenuButton<String>(
                    onSelected: (v) => v == 'edit' ? edit(row) : delete(row),
                    itemBuilder: (_) => [const PopupMenuItem(value: 'edit', child: Text('Sửa')),
                      const PopupMenuItem(value: 'delete', child: Text('Xóa'))],
                  ) : null,
                ));
              },
            )),
    );
  }
}
