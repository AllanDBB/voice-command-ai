// Infrastructure — audio capture via `record` package (16kHz, mono, PCM-16)
import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';

/// Callback receives signed 16-bit PCM samples (-32768..32767), one per audio sample.
typedef AudioChunkCallback = void Function(List<int> pcm16samples);

class AudioCaptureService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<List<int>>? _subscription;

  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> start(AudioChunkCallback onChunk) async {
    final granted = await requestPermission();
    if (!granted) throw Exception('Microphone permission denied');

    final stream = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );

    _subscription = stream.listen((rawBytes) {
      // record package gives raw PCM-16 LE bytes (2 bytes per sample).
      // Decode to signed Int16 samples so callers can divide by 32768.0.
      final bytes = Uint8List.fromList(rawBytes);
      final bd = bytes.buffer.asByteData();
      final samples = List<int>.generate(
        bytes.length ~/ 2,
        (i) => bd.getInt16(i * 2, Endian.little),
      );
      onChunk(samples);
    });
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  void dispose() {
    _subscription?.cancel();
    _recorder.dispose();
  }
}
