import 'package:flutter/material.dart';
import 'package:gym_tracker/data/local/local_store.dart';
import 'package:gym_tracker/shared/weight_units.dart';
import 'package:gym_tracker/theme/theme_switcher.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More'), actions: const [ThemeSwitcher()]),
      body: ListView(
        children: <Widget>[
          ValueListenableBuilder<WeightUnit>(
            valueListenable: LocalStore.instance.weightUnitListenable,
            builder: (context, unit, _) {
              final useKg = unit == WeightUnit.kilograms;
              return SwitchListTile(
                title: Text('Units: ${unit.displayName}'),
                value: useKg,
                onChanged: (value) {
                  final targetUnit = value ? WeightUnit.kilograms : WeightUnit.pounds;
                  LocalStore.instance.setWeightUnit(targetUnit);
                },
                subtitle: const Text('Toggle between kg/lb'),
              );
            },
          ),
          ListTile(
            title: const Text('e1RM Formula'),
            subtitle: const Text('Epley'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            title: const Text('Export (disabled)'),
            subtitle: const Text('Available when storage is added'),
            enabled: false,
          ),
          ListTile(
            title: const Text('Import (disabled)'),
            subtitle: const Text('Available when storage is added'),
            enabled: false,
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Privacy Lock'),
            subtitle: const Text('Requires biometrics; UI stub only'),
            value: false,
            onChanged: null,
          ),
        ],
      ),
    );
  }
}


