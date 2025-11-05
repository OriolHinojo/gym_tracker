import 'package:flutter/material.dart';
import 'package:gym_tracker/data/local/local_store.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search exercises',
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: LocalStore.instance.listExercisesRaw(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading exercises:\n${snapshot.error}'),
                  );
                }

                final exercises = snapshot.data ?? [];
                final q = _query.toLowerCase();
                final filtered = q.isEmpty
                    ? exercises
                    : exercises.where((e) {
                        final name = (e['name'] ?? '').toString().toLowerCase();
                        final cat = (e['category'] ?? '').toString().toLowerCase();
                        return name.contains(q) || cat.contains(q);
                      }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No exercises found'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final e = filtered[index];
                    final id = (e['id'] as num?)?.toInt();
                    final name = (e['name'] ?? 'Exercise').toString();
                    final category = (e['category'] ?? '—').toString();

                    return ListTile(
                      leading: const Icon(Icons.fitness_center_outlined),
                      title: Text(name),
                      subtitle: Text('Primary: $category'),
                      onTap: id == null
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ExerciseDetailScreen(id: id),
                                ),
                              ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add "create exercise" or import logic
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: LocalStore.instance.getExerciseRaw(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error loading exercise:\n${snapshot.error}'));
          }
          final exercise = snapshot.data;
          if (exercise == null) {
            return const Center(child: Text('Exercise not found'));
          }

          final name = (exercise['name'] ?? 'Exercise').toString();
          final category = (exercise['category'] ?? '—').toString();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              ListTile(
                title: Text(name, style: Theme.of(context).textTheme.titleLarge),
                subtitle: Text('Category: $category'),
              ),
              const SizedBox(height: 16),
              Card(
                child: SizedBox(
                  height: 200,
                  child: Center(
                    child: Text('Mini trends (chart) for "$name"'),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Card(
                child: ListTile(
                  title: Text('Auto-progression settings'),
                  subtitle: Text('UI only'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
