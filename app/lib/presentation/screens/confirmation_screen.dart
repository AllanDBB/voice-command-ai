// Presentation — Confirmation Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_command_provider.dart';
import '../widgets/voice_command_overlay.dart';
import '../theme/app_theme.dart';

class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VoiceCommandProvider>();
    final actionLabel = provider.pendingConfirmation ?? 'esta acción';

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: VoiceCommandOverlay(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Text('CONFIRMAR', style: kMono(11, color: kTextDim)),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 14),
                height: 1,
                color: kBorder,
              ),

              // ── Body ───────────────────────────────────────────────────
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Warning icon
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: kAmber.withValues(alpha: 0.1),
                            border: Border.all(
                              color: kAmber.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(Icons.priority_high_rounded,
                              color: kAmber, size: 34),
                        ),
                        const SizedBox(height: 28),

                        Text(
                          'Confirmar',
                          style: kDisplay(14).copyWith(color: kTextDim, letterSpacing: 2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          actionLabel,
                          style: kDisplay(28),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 48),

                        // YES / NO buttons
                        Row(
                          children: [
                            Expanded(
                              child: _ConfirmButton(
                                label: 'NO',
                                sublabel: 'cancelar',
                                color: kCoral,
                                onTap: () => provider.navigateTo(AppScreen.dashboard),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _ConfirmButton(
                                label: 'YES',
                                sublabel: 'confirmar',
                                color: kGreen,
                                onTap: () => provider.navigateTo(AppScreen.dashboard),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              CommandHintBar(kConfirmHints),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _ConfirmButton({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(
          children: [
            Text(label, style: kDisplay(28).copyWith(color: color)),
            const SizedBox(height: 4),
            Text(sublabel, style: kLabel(11, color: color.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}
