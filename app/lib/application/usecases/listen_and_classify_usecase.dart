// Application layer — use case: listen continuously and classify voice commands
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../../domain/entities/voice_command.dart';
import '../../infrastructure/audio/audio_capture_service.dart';
import '../../infrastructure/preprocessing/mel_spectrogram_extractor.dart';
import '../../infrastructure/inference/onnx_kws_interpreter.dart';

class ListenAndClassifyUseCase {
  final AudioCaptureService _audio;
  final MelSpectrogramExtractor _melSpec;
  final OnnxKWSInterpreter _kws;

  // Sliding window: 1s window, 200ms slide
  static const int _windowSamples = 16000;
  static const int _slideSamples = 3200;
  // Cooldown between detections — 1200ms prevents double-fires on long commands
  static const Duration _cooldown = Duration(milliseconds: 1200);

  DateTime? _lastDetection;
  final _commandController = StreamController<VoiceCommand>.broadcast();

  ListenAndClassifyUseCase({
    required AudioCaptureService audio,
    required MelSpectrogramExtractor melSpec,
    required OnnxKWSInterpreter kws,
  }) : _audio = audio,
       _melSpec = melSpec,
       _kws = kws;

  Stream<VoiceCommand> get commandStream => _commandController.stream;

  Future<void> start() async {
    final buffer = <int>[];

    await _audio.start((chunk) {
      buffer.addAll(chunk);

      while (buffer.length >= _windowSamples) {
        final window = buffer.sublist(0, _windowSamples);
        _processWindow(window);
        buffer.removeRange(0, _slideSamples);
      }
    });
  }

  /// RMS energy VAD: skip silent frames to avoid spurious predictions.
  /// Threshold ~0.008 ≈ -42 dBFS — well above digital silence but below speech.
  static const double _vadRmsThreshold = 0.008;

  void _processWindow(List<int> pcm16samples) {
    try {
      double sum = 0;
      for (final s in pcm16samples) { final f = s / 32768.0; sum += f * f; }
      final rms = math.sqrt(sum / pcm16samples.length);
      if (rms < _vadRmsThreshold) return;

      final floats = pcm16samples.map((s) => s / 32768.0).toList();
      final spectrogram = _melSpec.compute(floats);
      debugPrint('[KWS] spectrogram.length=${spectrogram.length} (expect 6464)');
      final command = _kws.run(spectrogram);
      debugPrint('[KWS] pred=${command.label} conf=${command.confidence.toStringAsFixed(3)}');

      if (command.isActionable) {
        final now = DateTime.now();
        if (_lastDetection == null ||
            now.difference(_lastDetection!) > _cooldown) {
          _lastDetection = now;
          _commandController.add(command);
        }
      }
    } catch (e, st) {
      debugPrint('[KWS] _processWindow error: $e\n$st');
    }
  }

  Future<void> stop() => _audio.stop();

  void dispose() {
    _commandController.close();
    _audio.dispose();
    _kws.dispose();
  }
}
