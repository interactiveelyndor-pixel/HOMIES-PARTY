import 'package:flutter/material.dart';

import '../network/network.dart';
import '../ui/app_palette.dart';
import '../ui/app_text_styles.dart';

/// Shown in the consent sheet and under Account. Keep in step with the terms version.
const communityRules = [
  'Be kind. No bullying, hate or harassment.',
  'No sharing personal details such as your real name, phone number or address.',
  'No cheating or abusing bugs.',
  'You can block or report anyone. Reports are reviewed by a person.',
  'Rooms are private: only people with the code can join.',
];

const ageChoices = {
  'under13': 'Under 13',
  '13_17': '13 to 17',
  '18plus': '18 or older',
};

/// Makes sure the signed-in player has accepted the current terms and given an
/// age range. Returns true when they may play online. Asks once, only when needed.
Future<bool> ensureConsent(BuildContext context, ApiClient api) async {
  final Eligibility current;
  try {
    current = await api.getEligibility();
  } catch (_) {
    return true; // Offline or server down: the server still enforces consent.
  }
  if (current.online) return true;
  if (!context.mounted) return false;
  final answer = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppPalette.backgroundElevated,
    builder: (_) => const _ConsentSheet(),
  );
  if (answer == null) return false;
  try {
    return (await api.acceptConsent(current.policyVersion, answer)).online;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not save. Try again.',
          ),
        ),
      );
    }
    return false;
  }
}

class _ConsentSheet extends StatefulWidget {
  const _ConsentSheet();

  @override
  State<_ConsentSheet> createState() => _ConsentSheetState();
}

class _ConsentSheetState extends State<_ConsentSheet> {
  String? _band;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Before you play online', style: AppTextStyles.title),
            const SizedBox(height: 12),
            const Text('Community rules', style: AppTextStyles.heading),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppPalette.panel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppPalette.ink, width: 2.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in communityRules)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2, right: 8),
                            child: Icon(Icons.check_circle_rounded, size: 18, color: AppPalette.mint),
                          ),
                          Expanded(child: Text(r, style: AppTextStyles.body)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('How old are you?', style: AppTextStyles.heading),
            const Text(
              'Under 13: private rooms only, no friend requests or Quick Match.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 8),
            for (final e in ageChoices.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _AgeTile(
                  key: Key('age_${e.key}'),
                  label: e.value,
                  selected: _band == e.key,
                  onTap: () => setState(() => _band = e.key),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const Key('consent_accept'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.confetti,
                  foregroundColor: AppPalette.ink,
                  textStyle: AppTextStyles.button,
                ),
                onPressed: _band == null
                    ? null
                    : () => Navigator.pop(context, _band),
                child: const Text('I agree and continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One age choice: a full-width sticker that turns yellow when chosen.
class _AgeTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _AgeTile({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? AppPalette.confetti : AppPalette.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppPalette.ink, width: 2.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: selected ? AppPalette.ink : AppPalette.textPrimary,
                  ),
                ),
              ),
              if (selected) const Icon(Icons.check_rounded, color: AppPalette.ink),
            ],
          ),
        ),
      ),
    );
  }
}
