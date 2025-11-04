import 'package:flutter/material.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: const <Widget>[
              FilterChip(label: Text('Bench Press'), selected: true, onSelected: null),
              FilterChip(label: Text('Last 8w'), selected: true, onSelected: null),
              FilterChip(label: Text('Avg e1RM'), selected: true, onSelected: null),
            ],
          ),
          const SizedBox(height: 16),
          const _ChartCard(title: 'e1RM Trend'),
          const SizedBox(height: 16),
          const _ChartCard(title: 'Volume Trend'),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 220,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Align(
            alignment: Alignment.topLeft,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
      ),
    );
  }
}


