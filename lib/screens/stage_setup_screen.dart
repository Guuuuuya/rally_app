import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../locator.dart' as locator_pkg;
import '../tracker.dart';

/// Configure the stage before the timer starts.
class StageSetupScreen extends StatefulWidget {
  final String groupId;
  const StageSetupScreen({super.key, required this.groupId});

  @override
  State<StageSetupScreen> createState() => _StageSetupScreenState();
}

class _StageSetupScreenState extends State<StageSetupScreen> {
  final _name = TextEditingController(text: 'Stage');
  String _type = 'Free drive';
  int _countdown = 3;
  double? _startLat, _startLng;

  Future<void> _useCurrentLocation() async {
    final pos = await locator_pkg.Locator.positions().first;
    setState(() {
      _startLat = pos.latitude;
      _startLng = pos.longitude;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Stage setup')),
      body: ListView(
        padding: const EdgeInsets.all(22),
        children: [
          Text('STAGE NAME',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.6, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            decoration: InputDecoration(
              filled: true,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          Text('ROUTE TYPE',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.6, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Free drive', label: Text('Free')),
              ButtonSegment(value: 'Sprint', label: Text('Sprint')),
              ButtonSegment(value: 'Loop', label: Text('Loop')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 20),
          Text('COUNTDOWN',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.6, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Off')),
              ButtonSegment(value: 3, label: Text('3s')),
              ButtonSegment(value: 5, label: Text('5s')),
              ButtonSegment(value: 10, label: Text('10s')),
            ],
            selected: {_countdown},
            onSelectionChanged: (s) => setState(() => _countdown = s.first),
          ),
          const SizedBox(height: 20),
          Text('START LOCATION',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.6, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _useCurrentLocation,
            icon: const Icon(Icons.my_location),
            label: Text(_startLat == null
                ? 'Set from current GPS'
                : '${_startLat!.toStringAsFixed(5)}, ${_startLng!.toStringAsFixed(5)}'),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.flag),
            label: const Text('GO'),
            onPressed: () async {
              await context.read<Tracker>().start(
                    widget.groupId,
                    name: _name.text.trim().isEmpty ? 'Stage' : _name.text.trim(),
                    type: _type,
                    countdownSec: _countdown,
                    startLat: _startLat,
                    startLng: _startLng,
                  );
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
