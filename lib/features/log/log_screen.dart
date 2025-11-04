import 'package:flutter/material.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key, this.workoutId});
  final String? workoutId;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  Duration _elapsed = Duration.zero;
  late final Ticker _ticker;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker((elapsed) {
      if (!_running) return;
      setState(() => _elapsed = elapsed);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String time = _format(_elapsed);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout'),
        actions: <Widget>[
          IconButton(onPressed: () {}, icon: const Icon(Icons.save_outlined)),
          FilledButton(onPressed: () {}, child: const Text('Finish')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Row(
            children: <Widget>[
              Chip(label: Text('Timer: $time')),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => setState(() => _running = !_running),
                icon: Icon(_running ? Icons.pause : Icons.play_arrow),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Expanded(child: Text('Bench Press')),
                      TextButton(onPressed: () {}, child: const Text('History')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _SetRow(index: 1),
                  const SizedBox(height: 8),
                  _SetRow(index: 2),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.add), label: const Text('Add set')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _format(Duration d) {
    final int m = d.inMinutes % 60;
    final int s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({required this.index});
  final int index;

  @override
  Widget build(BuildContext context) {
    final TextEditingController weight = TextEditingController(text: index == 1 ? '100.0' : '102.5');
    final TextEditingController reps = TextEditingController(text: index == 1 ? '5' : '4');
    return Row(
      children: <Widget>[
        SizedBox(width: 32, child: Center(child: Text('$index'))),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Weight'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: reps,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Reps'),
          ),
        ),
        const SizedBox(width: 8),
        Checkbox(value: index == 1, onChanged: (_) {}),
      ],
    );
  }
}

class Ticker {
  Ticker(this.onTick);
  final void Function(Duration) onTick;
  Duration _elapsed = Duration.zero;
  bool _running = false;
  void start() {
    _running = true;
    _tick();
  }

  void dispose() {
    _running = false;
  }

  Future<void> _tick() async {
    final Stopwatch sw = Stopwatch()..start();
    while (_running) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      _elapsed = sw.elapsed;
      onTick(_elapsed);
    }
  }
}


