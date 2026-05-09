// Presentation — Routines Screen
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_command_provider.dart';
import '../widgets/voice_command_overlay.dart';
import '../theme/app_theme.dart';

class RoutinesScreen extends StatelessWidget {
  const RoutinesScreen({super.key});

  static const _icons = ['☀', '◑', '▶'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VoiceCommandProvider>();
    final routines = provider.homeState.routines;
    final focusIdx = provider.homeState.routineFocusIndex;
    final running = provider.homeState.routineRunning;

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: VoiceCommandOverlay(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      color: kCyan,
                      onPressed: () => provider.navigateTo(AppScreen.dashboard),
                    ),
                    Text('RUTINAS', style: kDisplay(20)),
                    const Spacer(),
                    Text(
                      '${running.where((r) => r).length} activa(s)',
                      style: kMono(11, color: kTextDim),
                    ),
                  ],
                ),
              ),

              Container(
                margin: const EdgeInsets.symmetric(vertical: 14),
                height: 1,
                color: kBorder,
              ),

              // ── List ──────────────────────────────────────────────────────
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: routines.length,
                  separatorBuilder: (context, i) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final isFocused = i == focusIdx;
                    final isRunning = running.length > i && running[i];
                    return _RoutineRow(
                      name: routines[i],
                      icon: _icons[i % _icons.length],
                      isFocused: isFocused,
                      isRunning: isRunning,
                    );
                  },
                ),
              ),

              CommandHintBar(kRoutinesHints),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineRow extends StatelessWidget {
  final String name;
  final String icon;
  final bool isFocused;
  final bool isRunning;

  const _RoutineRow({
    required this.name,
    required this.icon,
    required this.isFocused,
    required this.isRunning,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: isFocused ? kCyanDim : kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFocused ? kCyan : kBorder,
          width: isFocused ? 1.5 : 1,
        ),
        boxShadow: isFocused
            ? [BoxShadow(color: kCyan.withValues(alpha: 0.18), blurRadius: 12)]
            : [],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Running indicator stripe
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 3,
              height: 36,
              decoration: BoxDecoration(
                color: isRunning ? kGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // Icon circle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isRunning
                    ? kGreen.withValues(alpha: 0.1)
                    : kBorder.withValues(alpha: 0.5),
                border: Border.all(
                  color: isRunning ? kGreen.withValues(alpha: 0.4) : Colors.transparent,
                ),
              ),
              child: Center(child: Text(icon, style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 14),

            // Name + status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: kLabel(16).copyWith(
                      fontWeight: isFocused ? FontWeight.w600 : FontWeight.w400,
                      color: isFocused ? kText : kTextDim,
                    ),
                  ),
                  if (isRunning) ...[
                    const SizedBox(height: 3),
                    Text('En ejecución', style: kLabel(11, color: kGreen)),
                  ],
                ],
              ),
            ),

            // go / stop indicators
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StateChip(label: 'GO', color: kGreen, active: isRunning),
                const SizedBox(width: 6),
                _StateChip(label: 'STOP', color: kCoral, active: !isRunning && isFocused),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StateChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;

  const _StateChip({required this.label, required this.color, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.6) : kBorder,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: kMono(9, color: active ? color : kTextDim),
      ),
    );
  }
}
