// Domain entity — represents a detected voice command
class VoiceCommand {
  final String label;
  final double confidence;
  final DateTime detectedAt;

  const VoiceCommand({
    required this.label,
    required this.confidence,
    required this.detectedAt,
  });

  static const List<String> labels = [
    'yes',
    'no',
    'up',
    'down',
    'left',
    'right',
    'on',
    'off',
    'stop',
    'go',
    '_silence_',
    '_unknown_',
  ];

  bool get isActionable =>
      label != '_silence_' && label != '_unknown_' && confidence >= 0.45;

  @override
  String toString() =>
      'VoiceCommand($label, ${(confidence * 100).toStringAsFixed(1)}%)';
}
