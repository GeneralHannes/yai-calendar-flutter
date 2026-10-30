import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/yai_theme.dart';

/// Calendar codes are case-insensitive and ignore spaces and dashes.
String normalizeCode(String raw) =>
    raw.toLowerCase().replaceAll(RegExp(r'[\s-]'), '');

bool isValidCode(String code) => code.length >= 8;

/// A fresh random code, e.g. `k7m2-x9qp-4tdw-h8ra` (no look-alike characters).
String newCode() {
  const alphabet = 'abcdefghjkmnpqrstuvwxyz23456789';
  final rng = Random.secure();
  final raw = List.generate(16, (_) => alphabet[rng.nextInt(alphabet.length)]);
  return [for (var i = 0; i < 16; i += 4) raw.sublist(i, i + 4).join()]
      .join('-');
}

/// First-run screen: enter the shared calendar's code, or start a new one.
class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key, required this.onJoin});

  final ValueChanged<String> onJoin;

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _field = TextEditingController();
  String? _created;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _submit() {
    final code = normalizeCode(_field.text);
    if (isValidCode(code)) widget.onJoin(code);
  }

  @override
  Widget build(BuildContext context) {
    final c = YaiPalette.of(context);
    final code = normalizeCode(_field.text);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Yai Calendar',
                  style: TextStyle(
                    fontFamily: YaiPalette.fontFamily,
                    fontSize: 36,
                    color: c.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'One calendar, shared by everyone with the same code.',
                  style: TextStyle(fontSize: 16, color: c.muted),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _field,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.go,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submit(),
                  style: TextStyle(fontSize: 18, color: c.ink),
                  decoration: InputDecoration(
                    labelText: 'Calendar code',
                    filled: true,
                    fillColor: c.bg2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: c.ink.withValues(alpha: .15)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: isValidCode(code) ? _submit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: c.gold,
                    foregroundColor: c.bg1,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Join calendar'),
                ),
                const SizedBox(height: 28),
                Divider(color: c.ink.withValues(alpha: .12)),
                const SizedBox(height: 12),
                if (_created == null)
                  OutlinedButton(
                    onPressed: () => setState(() => _created = newCode()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.gold,
                      minimumSize: const Size.fromHeight(52),
                      side: BorderSide(color: c.gold.withValues(alpha: .6)),
                    ),
                    child: const Text('Start a new calendar'),
                  )
                else ...[
                  Text('Your new code', style: TextStyle(color: c.muted)),
                  const SizedBox(height: 6),
                  SelectableText(
                    _created!,
                    style: TextStyle(
                      fontSize: 24,
                      letterSpacing: 1,
                      color: c.gold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Share it with everyone who should see this calendar. '
                    'Anyone with the code can read and edit it.',
                    style: TextStyle(color: c.muted),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    spacing: 12,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () =>
                              Clipboard.setData(ClipboardData(text: _created!)),
                          child: const Text('Copy'),
                        ),
                      ),
                      Expanded(
                        child: FilledButton(
                          onPressed: () =>
                              widget.onJoin(normalizeCode(_created!)),
                          style: FilledButton.styleFrom(
                            backgroundColor: c.gold,
                            foregroundColor: c.bg1,
                          ),
                          child: const Text('Use it'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
