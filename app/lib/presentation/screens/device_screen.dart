// Presentation — Device Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_command_provider.dart';
import '../widgets/voice_command_overlay.dart';
import '../theme/app_theme.dart';

class DeviceScreen extends StatelessWidget {
  const DeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VoiceCommandProvider>();
    final idx = provider.homeState.focusIndex
        .clamp(0, provider.homeState.devices.length - 1)
        .toInt();
    final device = provider.homeState.devices[idx];
    final isOn = device.state.name == 'on';

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: VoiceCommandOverlay(
          child: Column(
            children: [
              // ── Top bar ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      color: kCyan,
                      onPressed: () => provider.navigateTo(AppScreen.dashboard),
                    ),
                    Text('DISPOSITIVO', style: kMono(11, color: kTextDim)),
                    const Spacer(),
                    Text(device.name.toUpperCase(), style: kDisplay(16)),
                  ],
                ),
              ),

              Container(
                margin: const EdgeInsets.symmetric(vertical: 14),
                height: 1,
                color: kBorder,
              ),

              // ── Device hero ───────────────────────────────────────────────
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Device icon ring
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOut,
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOn
                              ? kAmber.withValues(alpha: 0.1)
                              : kSurface,
                          border: Border.all(
                            color: isOn
                                ? kAmber.withValues(alpha: 0.6)
                                : kBorder,
                            width: 1.5,
                          ),
                          boxShadow: isOn
                              ? [
                                  BoxShadow(
                                    color: kAmber.withValues(alpha: 0.2),
                                    blurRadius: 32,
                                    spreadRadius: 4,
                                  )
                                ]
                              : [],
                        ),
                        child: Center(
                          child: Text(
                            device.icon,
                            style: const TextStyle(fontSize: 52),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      Text(device.name, style: kDisplay(32)),
                      const SizedBox(height: 8),

                      // State pill
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 7),
                        decoration: BoxDecoration(
                          color: isOn
                              ? kAmber.withValues(alpha: 0.12)
                              : kCoral.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isOn
                                ? kAmber.withValues(alpha: 0.5)
                                : kCoral.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          isOn ? 'ENCENDIDO' : 'APAGADO',
                          style: kMono(13,
                              color: isOn ? kAmber : kCoral),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // ON / OFF command pills
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _CmdPill(
                            label: 'ON',
                            color: kAmber,
                            active: isOn,
                            onTap: () {},
                          ),
                          const SizedBox(width: 16),
                          _CmdPill(
                            label: 'OFF',
                            color: kCoral,
                            active: !isOn,
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              CommandHintBar(kDeviceHints),
            ],
          ),
        ),
      ),
    );
  }
}

class _CmdPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _CmdPill({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.15) : kSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: active ? color : kBorder,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Text(
        label,
        style: kDisplay(18).copyWith(
          color: active ? color : kTextDim,
        ),
      ),
    );
  }
}
