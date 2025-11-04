import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IronPulse')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          _SummaryRow(),
          SizedBox(height: 16),
          _Highlights(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.go('/log');
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Quick Start'),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const <Widget>[
        Expanded(child: _SummaryCard(title: 'This Week', value: '3 sessions')),
        SizedBox(width: 12),
        Expanded(child: _SummaryCard(title: 'Trend', value: 'e1RM +2.5 kg')),
        SizedBox(width: 12),
        Expanded(child: _SummaryCard(title: 'Last Session', value: 'Bench, Squat')),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.title, required this.value});
  final String title;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            Text('Highlights'),
            SizedBox(height: 8),
            ListTile(leading: Icon(Icons.emoji_events_outlined), title: Text('New 5RM PR on Bench')),
            ListTile(leading: Icon(Icons.trending_up), title: Text('e1RM +2.5 kg on Squat')),
          ],
        ),
      ),
    );
  }
}


