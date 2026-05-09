// Presentation — animated voice orb bar shown on all screens
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/voice_command_provider.dart';
import '../theme/app_theme.dart';
import '../../domain/entities/voice_command.dart';

class VoiceCommandOverlay extends StatefulWidget {
  final Widget child;
  const VoiceCommandOverlay({super.key, required this.child});

  @override
  State<VoiceCommandOverlay> createState() => _VoiceCommandOverlayState();
}

class _VoiceCommandOverlayState extends State<VoiceCommandOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _flashCtrl;
  VoiceCommand? _lastFlashed;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _flashCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VoiceCommandProvider>();
    final cmd = provider.lastCommand;

    if (provider.isListening && cmd != null && cmd.isActionable && cmd != _lastFlashed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _lastFlashed = cmd;
        _flashCtrl.forward(from: 0);
      });
    }

    return Column(
      children: [
        Expanded(child: widget.child),
        _VoiceBar(
          provider: provider,
          pulseCtrl: _pulseCtrl,
          flashCtrl: _flashCtrl,
        ),
      ],
    );
  }
}

class _VoiceBar extends StatelessWidget {
  final VoiceCommandProvider provider;
  final AnimationController pulseCtrl;
  final AnimationController flashCtrl;

  const _VoiceBar({
    required this.provider,
    required this.pulseCtrl,
    required this.flashCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final isListening = provider.isListening;
    final cmd = provider.lastCommand;
    final hasError = provider.initError != null && !isListening;

    void toggle() => isListening ? provider.stopListening() : provider.startListening();

    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        border: const Border(top: BorderSide(color: kBorder, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          // Animated mic orb
          GestureDetector(
            onTap: toggle,
            child: _MicOrb(
              isListening: isListening,
              hasError: hasError,
              pulseCtrl: pulseCtrl,
            ),
          ),
          const SizedBox(width: 14),
          // Status text + command flash
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: flashCtrl,
                  builder: (context, _) {
                    final t = flashCtrl.value;
                    final showing = t > 0 && t < 1 && cmd != null && cmd.isActionable;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: showing
                          ? _CommandFlash(cmd: cmd, key: ValueKey(cmd.label + cmd.detectedAt.toString()))
                          : _StatusLine(
                              isListening: isListening,
                              hasError: hasError,
                              errorText: provider.initError,
                              key: const ValueKey<String>('status'),
                            ),
                    );
                  },
                ),
                const SizedBox(height: 6),
                if (isListening && cmd != null && cmd.isActionable)
                  _ConfidenceBar(value: cmd.confidence),
              ],
            ),
          ),
          // Tap hint
          if (!isListening)
            Text('TAP', style: kMono(10, color: kTextDim)),
        ],
      ),
    );
  }
}

class _MicOrb extends StatelessWidget {
  final bool isListening;
  final bool hasError;
  final AnimationController pulseCtrl;

  const _MicOrb({
    required this.isListening,
    required this.hasError,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final color = hasError ? kCoral : isListening ? kCyan : kTextDim;

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isListening) ...[
            AnimatedBuilder(
              animation: pulseCtrl,
              builder: (context, child) => CustomPaint(
                size: const Size(52, 52),
                painter: _PulseRingPainter(progress: pulseCtrl.value, color: kCyan),
              ),
            ),
          ],
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isListening ? kCyanDim : kBorder,
              border: Border.all(color: color, width: 1.5),
            ),
            child: Icon(
              hasError ? Icons.mic_off : isListening ? Icons.mic : Icons.mic_none,
              color: color,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  const _PulseRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    for (int i = 0; i < 2; i++) {
      final phase = (progress + i * 0.5) % 1.0;
      final radius = 18.0 + phase * 14;
      final opacity = (1 - phase) * 0.5;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(_PulseRingPainter old) => old.progress != progress;
}

class _StatusLine extends StatelessWidget {
  final bool isListening;
  final bool hasError;
  final String? errorText;

  const _StatusLine({
    super.key,
    required this.isListening,
    required this.hasError,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Text(errorText ?? 'Error', style: kLabel(12, color: kCoral));
    }
    if (!isListening) {
      return Text('Micrófono inactivo', style: kLabel(13, color: kTextDim));
    }
    return Row(
      children: [
        Text('Escuchando', style: kLabel(13, color: kCyan)),
        const SizedBox(width: 6),
        _DotDot(),
      ],
    );
  }
}

class _DotDot extends StatefulWidget {
  @override
  State<_DotDot> createState() => _DotDotState();
}

class _DotDotState extends State<_DotDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final n = (_ctrl.value * 4).floor() % 4;
        return Text('.' * n + ' ' * (3 - n), style: kMono(13, color: kCyan));
      },
    );
  }
}

class _CommandFlash extends StatelessWidget {
  final VoiceCommand cmd;
  const _CommandFlash({super.key, required this.cmd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: kCyan.withValues(alpha: 0.15),
            border: Border.all(color: kCyan, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            cmd.label.toUpperCase(),
            style: kMono(14, color: kCyan),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(cmd.confidence * 100).toStringAsFixed(0)}%',
          style: kLabel(12, color: kTextDim),
        ),
      ],
    );
  }
}

class _ConfidenceBar extends StatelessWidget {
  final double value;
  const _ConfidenceBar({required this.value});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 2,
        backgroundColor: kBorder,
        valueColor: AlwaysStoppedAnimation<Color>(
          Color.lerp(kAmber, kCyan, math.min(1, value * 1.5)) ?? kCyan,
        ),
      ),
    );
  }
}

// ── Command hint strip ────────────────────────────────────────────────────────
// Each screen can show a compact guide of what commands do.

class CommandHintBar extends StatelessWidget {
  final List<CmdHint> hints;
  const CommandHintBar(this.hints, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: kBorder, width: 1)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: hints.map((h) => _HintChip(h)).toList(),
      ),
    );
  }
}

class CmdHint {
  final String command;
  final String action;
  final Color color;
  const CmdHint(this.command, this.action, {this.color = kTextDim});
}

class _HintChip extends StatelessWidget {
  final CmdHint hint;
  const _HintChip(this.hint);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(color: hint.color.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Text(hint.command, style: kMono(10, color: hint.color)),
        ),
        const SizedBox(width: 4),
        Text(hint.action, style: kLabel(10, color: kTextDim)),
      ],
    );
  }
}

// Re-export hints for screens
const kDashboardHints = [
  CmdHint('up/down/left/right', 'navegar', color: kCyan),
  CmdHint('yes / go', 'entrar', color: kGreen),
];

const kDeviceHints = [
  CmdHint('on / go', 'encender', color: kAmber),
  CmdHint('off', 'apagar', color: kCoral),
  CmdHint('left / stop', 'volver', color: kTextDim),
];

const kRoutinesHints = [
  CmdHint('up/down', 'mover foco', color: kCyan),
  CmdHint('go', 'ejecutar', color: kGreen),
  CmdHint('stop / left', 'detener/volver', color: kCoral),
];

const kConfirmHints = [
  CmdHint('yes', 'confirmar', color: kGreen),
  CmdHint('no', 'cancelar', color: kCoral),
];
