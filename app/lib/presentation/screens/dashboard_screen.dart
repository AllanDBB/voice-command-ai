// Presentation — Dashboard Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_command_provider.dart';
import '../widgets/focusable_card.dart';
import '../widgets/voice_command_overlay.dart';
import '../theme/app_theme.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VoiceCommandProvider>();
    final devices = provider.homeState.devices;
    final focusIdx = provider.homeState.focusIndex;
    final isListening = provider.isListening;

    // Items: devices + routines card
    final itemCount = devices.length + 1; // +1 for Routines

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: VoiceCommandOverlay(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('VOICE HOME', style: kDisplay(22)),
                        const SizedBox(height: 2),
                        Text('Control por voz', style: kLabel(13, color: kTextDim)),
                      ],
                    ),
                    const Spacer(),
                    // Mic status badge
                    GestureDetector(
                      onTap: () => isListening
                          ? provider.stopListening()
                          : provider.startListening(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isListening
                              ? kCyan.withValues(alpha: 0.12)
                              : kBorder,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isListening ? kCyan : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isListening ? Icons.mic : Icons.mic_none,
                              color: isListening ? kCyan : kTextDim,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isListening ? 'ACTIVO' : 'INACTIVO',
                              style: kMono(10,
                                  color: isListening ? kCyan : kTextDim),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Divider ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Container(height: 1, color: kBorder),
              ),

              // ── Section label ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text('DISPOSITIVOS', style: kMono(11, color: kTextDim)),
              ),

              // ── Grid ─────────────────────────────────────────────────────
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: itemCount,
                    itemBuilder: (context, i) {
                      if (i < devices.length) {
                        final d = devices[i];
                        return FocusableCard(
                          title: d.name,
                          icon: d.icon,
                          isFocused: focusIdx == i,
                          isOn: d.state.name == 'on',
                          onTap: () => provider.navigateTo(AppScreen.device),
                        );
                      } else {
                        // Routines card
                        return FocusableCard(
                          title: 'Rutinas',
                          icon: '⚙',
                          isFocused: focusIdx == i,
                          onTap: () => provider.navigateTo(AppScreen.routines),
                        );
                      }
                    },
                  ),
                ),
              ),

              // ── Command hints ─────────────────────────────────────────────
              CommandHintBar(kDashboardHints),
            ],
          ),
        ),
      ),
    );
  }
}
