import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../db.dart';
import '../theme.dart';

/// Sign in anonymously, then create a group (get 4-digit pin) or join one.
/// Styled to match the Figma "Group" screen.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _name = TextEditingController();
  final _pin = List.generate(4, (_) => TextEditingController());
  bool _busy = false;
  bool _created = false;
  String? _createdCode;

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
    final cs = Theme.of(context).colorScheme;
    final theme = context.watch<ThemeNotifier>();
    final code = _pin.map((c) => c.text).join();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 56, 22, 24),
        children: [
          Row(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.route, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text('RALLYTRACK',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800, letterSpacing: 1.6)),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: theme.toggle,
                icon: Icon(theme.isLight
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.group, color: cs.primary, size: 44),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text('DRIVE TOGETHER',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 2, color: cs.onSurfaceVariant)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('Build your rally crew.',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Create a private group or join friends with a four-digit PIN.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('DISPLAY NAME',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.6, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(
                      hintText: 'Alex K.',
                      prefixIcon: const Icon(Icons.person_outline),
                      suffixIcon: _name.text.isNotEmpty
                          ? Icon(Icons.check, color: cs.primary)
                          : null,
                      filled: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _busy
                          ? null
                          : () async {
                              final name = _name.text.trim().isEmpty
                                  ? 'Driver'
                                  : _name.text.trim();
                              String? code;
                              await _submit(() async {
                                code = await context.read<Db>().createGroup(name);
                              });
                              if (code != null && mounted) {
                                setState(() {
                                  _created = true;
                                  _createdCode = code;
                                });
                              }
                            },
                      icon: const Icon(Icons.group_outlined),
                      label: Text(_created ? 'Group created ✓' : 'Create a group'),
                    ),
                  ),
                  if (_created && _createdCode != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check, color: cs.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Group PIN $_createdCode is ready to share',
                              style: TextStyle(color: cs.primary),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() {
                              _name.clear();
                              _created = false;
                              _createdCode = null;
                            }),
                            child: const Text('DONE'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('OR JOIN A GROUP',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                    letterSpacing: 1.6,
                                    color: cs.onSurfaceVariant)),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('ENTER GROUP PIN',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.6, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(4, (i) {
                      return SizedBox(
                        width: 58,
                        child: TextField(
                          controller: _pin[i],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none),
                          ),
                          onChanged: (v) {
                            if (v.isNotEmpty && i < 3) {
                              FocusScope.of(context).nextFocus();
                            }
                            setState(() {});
                          },
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _busy || code.length != 4
                          ? null
                          : () async {
                              await _submit(() async {
                                final ok = await context
                                    .read<Db>()
                                    .joinByCode(code);
                                if (ok == null) throw Exception('Invalid pin');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Joined! Open the Stage tab.')),
                                  );
                                }
                              });
                            },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Join group'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Groups are private. Only people with your PIN can join.',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
