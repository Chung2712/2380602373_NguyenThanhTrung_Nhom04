import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/api/api.dart';
import '../../core/utils/feedback.dart';

class MotionScreen extends StatefulWidget {
  const MotionScreen({super.key});
  @override State<MotionScreen> createState() => _MotionScreenState();
}

class _MotionScreenState extends State<MotionScreen> {
  List<Map<String, dynamic>> devices = [];
  StreamSubscription<UserAccelerometerEvent>? subscription;
  String? selectedId;
  bool monitoring = false;
  double score = 0;
  double baselineNoise = 0;
  int calibrationSamples = 0;
  bool calibrating = false;
  int alarmCount = 0;
  int sensitivity = 5;
  DateTime? lastAlarm;
  DateTime? startedAt;
  bool sending = false;
  DateTime? lastUiUpdate;
  String status = 'Chưa bật giám sát';

  @override void initState() { super.initState(); load(); }
  @override void dispose() { subscription?.cancel(); super.dispose(); }

  Future<void> load() async {
    try { final list = await Api.instance.list('devices');
      if (mounted) setState(() {
        devices = list.where((x) => x['isArmed'] == true).toList();
        if (devices.isEmpty) selectedId = null;
        else if (!devices.any((x) => x['id']?.toString() == selectedId)) selectedId = devices.first['id'].toString();
      });
    } catch (e) { if (mounted) showError(context, e); }
  }

  void begin() {
    if (selectedId == null) { showNotice(context, 'Hãy bật bảo vệ cho ít nhất một thiết bị.'); return; }
    subscription?.cancel();
    startedAt = DateTime.now();
    lastAlarm = null;
    alarmCount = 0;
    baselineNoise = 0;
    calibrationSamples = 0;
    calibrating = true;
    lastUiUpdate = null;
    subscription = userAccelerometerEventStream(samplingPeriod: SensorInterval.normalInterval).listen(
      (e) {
        final magnitude = math.sqrt(e.x * e.x + e.y * e.y + e.z * e.z);
        if (!mounted) return;
        final nowForUi = DateTime.now();
        if (lastUiUpdate == null || nowForUi.difference(lastUiUpdate!).inMilliseconds >= 200) {
          lastUiUpdate = nowForUi;
          setState(() => score = magnitude);
        }
        if (DateTime.now().difference(startedAt!).inSeconds < 3) {
          baselineNoise = (baselineNoise * calibrationSamples + magnitude) / (++calibrationSamples);
          return;
        }
        if (calibrating) {
          calibrating = false;
          setState(() => status = 'Đang giám sát chuyển động');
        }
        final threshold = math.max(7.0 - 0.5 * sensitivity, baselineNoise * 3.0 + 0.5);
        // Adaptive threshold uses ambient noise measured during 3s calibration.
        final now = DateTime.now();
        if (magnitude < threshold || sending ||
            (lastAlarm != null && now.difference(lastAlarm!).inSeconds < 8)) return;
        lastAlarm = now;
        send(magnitude);
      }, onError: (Object error) {
        if (mounted) { stop(); showError(context, error); }
      },
    );
    setState(() { monitoring = true; status = 'Đang hiệu chỉnh 3 giây đầu...'; });
  }

  void stop() {
    subscription?.cancel(); subscription = null;
    if (mounted) setState(() { monitoring = false; status = 'Đã dừng giám sát'; });
  }

  Future<void> send(double magnitude) async {
    sending = true;
    if (mounted) setState(() { alarmCount++; status = 'Phát hiện rung ${magnitude.toStringAsFixed(1)} m/s²'; });
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.vibrate();
    try {
      await Api.instance.request('POST', '/api/events/devices/$selectedId',
        {'motionScore': magnitude.clamp(0.0, 100.0)});
      if (mounted) setState(() => status = 'Đã gửi cảnh báo lên API');
    } catch (e) { if (mounted) setState(() => status = 'Lỗi gửi cảnh báo: ${humanError(e)}'); }
    finally { sending = false; }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Giám sát chuyển động'),
      actions: [IconButton(onPressed: monitoring ? null : load, icon: const Icon(Icons.refresh))]),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Card(child: Padding(padding: const EdgeInsets.all(22), child: Column(children: [
        Icon(monitoring ? Icons.sensors : Icons.sensors_off, size: 72,
          color: monitoring ? Colors.teal : Colors.grey),
        const SizedBox(height: 12),
        Text(status, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Text('${score.toStringAsFixed(2)} m/s²',
          style: const TextStyle(fontSize: 38, fontWeight: FontWeight.bold)),
        Text('Số lần cảnh báo: $alarmCount'),
        Text('Độ rung nền: ${baselineNoise.toStringAsFixed(2)} m/s²'),
        Text('Ngưỡng thích ứng: ${math.max(7.0 - 0.5 * sensitivity, baselineNoise * 3.0 + 0.5).toStringAsFixed(2)} m/s²'),
      ]))),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        key: ValueKey(selectedId), initialValue: selectedId,
        decoration: const InputDecoration(labelText: 'Thiết bị đang bật bảo vệ'),
        items: devices.map((d) => DropdownMenuItem<String>(
          value: d['id'].toString(), child: Text('${d['name']} (${d['deviceCode']})'))).toList(),
        onChanged: monitoring ? null : (v) => setState(() => selectedId = v),
      ),
      const SizedBox(height: 14),
      Text('Độ nhạy: $sensitivity/10'),
      Slider(value: sensitivity.toDouble(), min: 1, max: 10, divisions: 9,
        label: '$sensitivity', onChanged: monitoring ? null : (v) => setState(() => sensitivity = v.toInt())),
      const SizedBox(height: 14),
      FilledButton.icon(onPressed: monitoring ? stop : begin,
        icon: Icon(monitoring ? Icons.stop_circle_outlined : Icons.play_arrow),
        label: Text(monitoring ? 'Dừng giám sát' : 'Bắt đầu giám sát')),
      const SizedBox(height: 18),
      const Text('Ý tưởng sáng tạo (bản đầu): tự đo mức rung nền trong 3 giây để điều chỉnh ngưỡng, giảm báo giả. '
        'App không tự chạy ngầm hoặc gửi thông báo push. Độ nhạy là ngưỡng thử nghiệm, '
        'Cảm biến hoạt động khi màn hình này còn mở. Đây chưa phải hệ thống bảo vệ hoàn chỉnh.'),
    ]),
  );
}
