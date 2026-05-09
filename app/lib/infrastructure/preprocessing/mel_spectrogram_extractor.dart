// Infrastructure — Mel Spectrogram extractor in pure Dart
// Matches Python: MelSpectrogram(sample_rate=16000, n_mels=64, n_fft=1024, hop_length=160)
// Output: Float32List of shape [1, 1, 64, 101] flattened
import 'dart:math' as math;
import 'dart:typed_data';

class NormStats {
  final double mean;
  final double std;
  const NormStats({required this.mean, required this.std});
}

class MelSpectrogramExtractor {
  static const int sampleRate = 16000;
  static const int nMels = 64;
  static const int nFft = 1024;
  static const int hopLength = 160;
  static const double fMin = 20.0;
  static const double fMax = 8000.0;

  late final List<List<double>> _melFilterbank;
  late final List<double> _hannWindow;
  final NormStats normStats;

  MelSpectrogramExtractor({required this.normStats}) {
    _hannWindow = _buildHannWindow(nFft);
    _melFilterbank = _buildMelFilterbank();
  }

  /// Computes Mel spectrogram and returns flat Float32List (shape [1,1,64,101]).
  /// Matches torchaudio exactly:
  ///   - center=True: pad nFft//2 zeros on each side
  ///   - power=2.0: filterbank applied to power spectrum
  ///   - AmplitudeToDB(stype='power'): 10*log10
  ///   - periodic Hann window
  ///   - NO pre-emphasis
  Float32List compute(List<double> samples) {
    // Center padding: nFft//2 zeros on each side (torchaudio default center=True)
    final pad = nFft ~/ 2;
    final padded = List<double>.filled(samples.length + 2 * pad, 0.0);
    for (int i = 0; i < samples.length; i++) {
      padded[i + pad] = samples[i];
    }

    // Number of frames — should be 101 for 16000 samples
    final nFrames = (padded.length - nFft) ~/ hopLength + 1;

    final result = Float32List(1 * 1 * nMels * nFrames);

    // Build STFT power spectrum and apply Mel filterbank.
    // Output layout must match PyTorch [1, 1, n_mels, n_frames] = mel-major:
    //   flat index = m * nFrames + t   (NOT t * nMels + m)
    for (int t = 0; t < nFrames; t++) {
      final start = t * hopLength;
      final frame = List<double>.generate(nFft, (i) {
        final sampleIdx = start + i;
        final s = sampleIdx < padded.length ? padded[sampleIdx] : 0.0;
        return s * _hannWindow[i];
      });

      // Power spectrum: |X[k]|^2  (matches torchaudio power=2.0)
      final power = _fftPower(frame);

      for (int m = 0; m < nMels; m++) {
        double energy = 0.0;
        for (int k = 0; k < power.length; k++) {
          energy += _melFilterbank[m][k] * power[k];
        }
        // AmplitudeToDB with stype='power': 10*log10(max(1e-10, energy))
        final db = 10.0 * math.log(math.max(1e-10, energy)) / math.ln10;
        // Normalize — store mel-major so layout matches [1,1,64,101] tensor
        result[m * nFrames + t] = (db - normStats.mean) / normStats.std;
      }
    }

    return result;
  }

  // ── helpers ────────────────────────────────────────────────────────────────

  List<double> _buildHannWindow(int n) {
    // Periodic Hann window: matches torch.hann_window(n_fft) default periodic=True
    return List<double>.generate(
      n,
      (i) => 0.5 * (1 - math.cos(2 * math.pi * i / n)),
    );
  }

  /// Power spectrum (half) via radix-2 Cooley-Tukey FFT: returns |X[k]|^2
  List<double> _fftPower(List<double> frame) {
    final n = frame.length;
    final re = List<double>.from(frame);
    final im = List<double>.filled(n, 0.0);
    _fftInPlace(re, im, n);
    // Only first n/2+1 bins (positive frequencies)
    return List<double>.generate(n ~/ 2 + 1, (k) {
      return re[k] * re[k] + im[k] * im[k];
    });
  }

  void _fftInPlace(List<double> re, List<double> im, int n) {
    if (n <= 1) return;
    // Bit-reversal permutation
    int j = 0;
    for (int i = 1; i < n; i++) {
      int bit = n >> 1;
      while ((j & bit) != 0) {
        j ^= bit;
        bit >>= 1;
      }
      j ^= bit;
      if (i < j) {
        final tmpR = re[i];
        re[i] = re[j];
        re[j] = tmpR;
        final tmpI = im[i];
        im[i] = im[j];
        im[j] = tmpI;
      }
    }
    // Cooley-Tukey iterative FFT
    for (int len = 2; len <= n; len <<= 1) {
      final ang = -2 * math.pi / len;
      final wRe = math.cos(ang);
      final wIm = math.sin(ang);
      for (int i = 0; i < n; i += len) {
        double curRe = 1.0, curIm = 0.0;
        for (int k = 0; k < len ~/ 2; k++) {
          final uRe = re[i + k];
          final uIm = im[i + k];
          final vRe =
              re[i + k + len ~/ 2] * curRe - im[i + k + len ~/ 2] * curIm;
          final vIm =
              re[i + k + len ~/ 2] * curIm + im[i + k + len ~/ 2] * curRe;
          re[i + k] = uRe + vRe;
          im[i + k] = uIm + vIm;
          re[i + k + len ~/ 2] = uRe - vRe;
          im[i + k + len ~/ 2] = uIm - vIm;
          final newRe = curRe * wRe - curIm * wIm;
          curIm = curRe * wIm + curIm * wRe;
          curRe = newRe;
        }
      }
    }
  }

  /// Build Mel filterbank [nMels x (nFft/2+1)]
  List<List<double>> _buildMelFilterbank() {
    double hzToMel(double hz) => 2595.0 * math.log(1 + hz / 700.0) / math.ln10;
    double melToHz(double mel) => 700.0 * (math.pow(10, mel / 2595.0) - 1);

    final melMin = hzToMel(fMin);
    final melMax = hzToMel(fMax);
    final melPoints = List<double>.generate(
      nMels + 2,
      (i) => melMin + i * (melMax - melMin) / (nMels + 1),
    );
    final hzPoints = melPoints.map(melToHz).toList();
    final bins = hzPoints
        .map((hz) => (hz * (nFft + 1) / sampleRate).floor())
        .toList();

    return List<List<double>>.generate(nMels, (m) {
      return List<double>.generate(nFft ~/ 2 + 1, (k) {
        if (k < bins[m] || k > bins[m + 2]) return 0.0;
        if (k <= bins[m + 1]) {
          return (k - bins[m]) / (bins[m + 1] - bins[m] + 1e-8);
        } else {
          return (bins[m + 2] - k) / (bins[m + 2] - bins[m + 1] + 1e-8);
        }
      });
    });
  }
}
