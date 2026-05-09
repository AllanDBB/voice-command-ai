// Infrastructure — ONNX Runtime Mobile KWS interpreter
// Mandatory per project rubric
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import '../../domain/entities/voice_command.dart';

class OnnxKWSInterpreter {
  static const String _modelAsset = 'assets/models/kws_model.onnx';
  OrtSession? _session;

  Future<void> load() async {
    OrtEnv.instance.init();
    final rawBytes = await rootBundle.load(_modelAsset);
    final bytes = rawBytes.buffer.asUint8List();
    final sessionOptions = OrtSessionOptions();
    _session = OrtSession.fromBuffer(bytes, sessionOptions);
  }

  /// Runs inference on a flattened Float32List of shape [1,1,64,101]
  VoiceCommand run(Float32List spectrogram) {
    assert(_session != null, 'Call load() before run()');

    final inputTensor = OrtValueTensor.createTensorWithDataList(spectrogram, [
      1,
      1,
      64,
      101,
    ]);

    final inputs = {'spectrogram': inputTensor};
    final runOptions = OrtRunOptions();
    final outputs = _session!.run(runOptions, inputs);

    // Output: logits [1, 12]
    final logits = (outputs[0]?.value as List<dynamic>)[0] as List<dynamic>;
    final floatLogits = logits.map((v) => (v as double)).toList();

    final probs = _softmax(floatLogits);
    int argmax = 0;
    double maxP = probs[0];
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > maxP) {
        maxP = probs[i];
        argmax = i;
      }
    }

    inputTensor.release();
    runOptions.release();
    for (final o in outputs) {
      o?.release();
    }

    return VoiceCommand(
      label: VoiceCommand.labels[argmax],
      confidence: maxP,
      detectedAt: DateTime.now(),
    );
  }

  List<double> _softmax(List<double> logits) {
    final maxVal = logits.reduce((a, b) => a > b ? a : b);
    final exps = logits
        .map((x) => math.exp((x - maxVal).clamp(-500.0, 0.0)))
        .toList();
    final sum = exps.reduce((a, b) => a + b);
    return exps.map((e) => e / sum).toList();
  }

  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
  }
}
