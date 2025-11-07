import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/shared/session_detail.dart';
import 'package:gym_tracker/widgets/workout_editor.dart' show showWorkoutEditorPage;
import 'package:gym_tracker/widgets/session_detail_body.dart';
import 'package:gym_tracker/widgets/session_primary_action_button.dart';

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({super.key, required this.id});

  final int id;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  late Future<SessionDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<SessionDetail> _load() {
    return loadSessionDetail(widget.id);
  }

  Future<void> _confirmDelete(int workoutId) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete workout?'),
        content: const Text('This will remove the workout and its sets permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;
    await LocalStore.instance.deleteWorkout(workoutId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Workout deleted')));
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
          tooltip: 'Back',
        ),
        title: const Text('Session'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete workout',
            onPressed: () async {
              try {
                final vm = await _future;
                if (!mounted) return;
                await _confirmDelete(vm.id);
              } catch (_) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Workout not available')));
              }
            },
          ),
        ],
      ),
      floatingActionButton: FutureBuilder<SessionDetail>(
        future: _future,
        builder: (context, snapshot) {
          final vm = snapshot.data;
          if (vm == null) return const SizedBox.shrink();
          return SessionPrimaryActionButton(
            label: 'Edit',
            onPressed: () => showWorkoutEditorPage(
              context,
              editWorkoutId: vm.id,
            ),
          );
        },
      ),
      body: FutureBuilder<SessionDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Unable to load workout.\n${snapshot.error}'));
          }

          final vm = snapshot.data!;
          return SessionDetailBody(detail: vm);
        },
      ),
    );
  }
}
