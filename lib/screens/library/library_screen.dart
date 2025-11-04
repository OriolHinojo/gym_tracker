import 'package:flutter/material.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search exercises'),
              onChanged: (v) {},
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: 10,
              itemBuilder: (context, index) {
                final String id = 'ex$index';
                return ListTile(
                  leading: const Icon(Icons.fitness_center_outlined),
                  title: Text('Exercise #$index'),
                  subtitle: const Text('Primary: Chest'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ExerciseDetailScreen(id: id)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(onPressed: () {}, child: const Icon(Icons.add)),
    );
  }
}

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const <Widget>[
          ListTile(title: Text('Bench Press'), subtitle: Text('Notes and metadata')),
          SizedBox(height: 16),
          Card(child: SizedBox(height: 200, child: Center(child: Text('Mini trends (chart)')))),
          SizedBox(height: 16),
          Card(child: ListTile(title: Text('Auto-progression settings'), subtitle: Text('UI only'))),
        ],
      ),
    );
  }
}


