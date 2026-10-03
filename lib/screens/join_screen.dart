import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db.dart';

/// Sign in anonymously, then create a group (get 4-digit pin) or join one.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _name = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;

  Future<void> _submit(Future<void> Function() op) async {
    setState(() => _busy = true);
    final db = context.read<Db>();
    await db.signInAnonymously();
    await db.setProfile(_name.text.trim().isEmpty ? 'Driver' : _name.text.trim());
    try {
      await op();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RallyTrack')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : () async {
                final name = _name.text.trim().isEmpty
                    ? 'Driver'
                    : _name.text.trim();
                String? code;
                await _submit(() async {
                  code = await context.read<Db>().createGroup(name);
                });
                if (code != null && mounted) {
                  await showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Group created'),
                      content: Text('Share this 4-digit pin to join:\n\n'
                          '$code'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context); // close dialog
                            Navigator.of(context).pop(); // back to home
                          },
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                }
              },
              child: const Text('Create Group'),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: '4-digit group pin',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
            FilledButton(
              onPressed: _busy || _code.text.length != 4
                  ? null
                  : () => _submit(() async {
                        final ok =
                            await context.read<Db>().joinByCode(_code.text);
                        if (ok == null) throw Exception('Invalid pin');
                        if (mounted) Navigator.of(context).pop();
                      }),
              child: const Text('Join Group'),
            ),
          ],
        ),
      ),
    );
  }
}
