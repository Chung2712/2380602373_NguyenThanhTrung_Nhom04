import 'package:flutter/material.dart';
import '../../core/api/api.dart';
import '../../core/utils/feedback.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});
  @override State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  List<Map<String, dynamic>> events = [];
  bool loading = true;
  String? error;
  @override void initState() { super.initState(); refresh(); }

  Future<void> refresh() async {
    setState(() { loading = true; error = null; });
    try { final result = await Api.instance.list('events');
      if (mounted) setState(() => events = result);
    } catch (e) { if (mounted) setState(() => error = humanError(e)); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> acknowledge(Map<String, dynamic> event) async {
    try { await Api.instance.request('POST', '/api/events/${event['id']}/acknowledge');
      if (mounted) { showNotice(context, 'Đã xác nhận cảnh báo'); refresh(); }
    } catch (e) { if (mounted) showError(context, e); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch sử cảnh báo'),
      actions: [IconButton(onPressed: refresh, icon: const Icon(Icons.refresh))]),
    body: loading ? const Center(child: CircularProgressIndicator())
      : error != null ? Center(child: Text(error!))
      : events.isEmpty ? const Center(child: Text('Chưa có cảnh báo'))
      : RefreshIndicator(onRefresh: refresh, child: ListView.builder(
          padding: const EdgeInsets.all(12), itemCount: events.length,
          itemBuilder: (context, i) {
            final e = events[i];
            final ack = e['acknowledgedAt'] != null;
            return Card(child: Padding(padding: const EdgeInsets.all(8), child: ListTile(
              leading: CircleAvatar(backgroundColor: e['severity'] == 'Critical' ? Colors.red.shade100 : Colors.amber.shade100,
                child: const Icon(Icons.warning_amber)),
              title: Text('${e['deviceName']} – ${e['severity']}'),
              subtitle: Text('Chuyển động: ${e['motionScore']}\n${e['occurredAt']}'),
              isThreeLine: true,
              trailing: ack ? const Icon(Icons.check_circle, color: Colors.green)
                : TextButton(onPressed: () => acknowledge(e), child: const Text('Xác nhận')),
            )));
          })),
  );
}
