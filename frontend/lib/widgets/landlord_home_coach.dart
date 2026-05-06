import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kLandlordHomeCoachPrefsKeyBase =
    'kirayaease_landlord_home_coach_v1_done';

/// One-time multi-step “coach marks” style tour for the landlord Home tab.
Future<void> showLandlordHomeCoachIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final email = (prefs.getString('user_email') ?? '').trim().toLowerCase();
  final key = email.isEmpty
      ? kLandlordHomeCoachPrefsKeyBase
      : '${kLandlordHomeCoachPrefsKeyBase}_$email';
  if (prefs.getBool(key) == true) return;
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _LandlordCoachDialog(),
  );

  await prefs.setBool(key, true);
}

class _LandlordCoachDialog extends StatefulWidget {
  const _LandlordCoachDialog();

  @override
  State<_LandlordCoachDialog> createState() => _LandlordCoachDialogState();
}

class _LandlordCoachDialogState extends State<_LandlordCoachDialog> {
  int _step = 0;

  static const _steps = <_CoachStep>[
    _CoachStep(
      title: 'This is your assistant',
      body:
          'Everything on Home revolves around this chat. Type questions in your own words, or tap a shortcut below the greeting.',
    ),
    _CoachStep(
      title: 'Switch property context',
      body:
          'Use the row under the logo to work across your whole portfolio or focus on one lease.',
    ),
    _CoachStep(
      title: 'Add properties & leases',
      body:
          'Open Settings (bottom bar) → Properties to view or add units. You can also attach a lease PDF here or say “create a lease”.',
    ),
    _CoachStep(
      title: 'Typical next steps',
      body:
          'After a lease is saved: send it for signature (DocuSeal), send rent reminders, or mark rent paid — just ask here.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    final isLast = _step == _steps.length - 1;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        step.title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              step.body,
              style: const TextStyle(
                fontSize: 15,
                height: 1.45,
                color: Color(0xFF4A4A4A),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: List.generate(_steps.length, (i) {
                return Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < _steps.length - 1 ? 6 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: i <= _step
                          ? const Color(0xFF1AAE9F)
                          : const Color(0xFFE8E8E8),
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Skip'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF1AAE9F),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            if (isLast) {
              Navigator.of(context).pop();
            } else {
              setState(() => _step++);
            }
          },
          child: Text(isLast ? 'Got it' : 'Next'),
        ),
      ],
    );
  }
}

class _CoachStep {
  final String title;
  final String body;

  const _CoachStep({required this.title, required this.body});
}
