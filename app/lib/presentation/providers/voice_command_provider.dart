// Presentation — Voice Command state provider
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/voice_command.dart';
import '../../domain/entities/smart_home_state.dart';
import '../../application/usecases/listen_and_classify_usecase.dart';
import '../../application/usecases/execute_command_usecase.dart';
import '../../infrastructure/audio/audio_capture_service.dart';
import '../../infrastructure/preprocessing/mel_spectrogram_extractor.dart';
import '../../infrastructure/inference/onnx_kws_interpreter.dart';
import '../../infrastructure/lm/litert_lm_service.dart';

enum AppScreen { dashboard, device, routines, confirmation }

class VoiceCommandProvider extends ChangeNotifier {
  ListenAndClassifyUseCase? _listenUseCase;
  final ExecuteCommandUseCase _executeUseCase = ExecuteCommandUseCase();
  LiteRTLMService? _lmService;

  VoiceCommand? lastCommand;
  SmartHomeState homeState = SmartHomeState.initial();
  AppScreen currentScreen = AppScreen.dashboard;
  String? pendingConfirmation;
  bool isListening = false;
  bool isInitialized = false;
  String? initError;

  StreamSubscription<VoiceCommand>? _sub;

  VoiceCommandProvider();

  /// Initializes audio, mel spectrogram, KWS and LM asynchronously.
  /// Called right after construction so runApp() is never blocked.
  Future<void> initAsync() async {
    // Mark initialized immediately so the UI renders right away.
    // Infrastructure services initialize in the background.
    isInitialized = true;
    notifyListeners();
    try {
      final statsJson = await rootBundle.loadString(
        'assets/models/norm_stats.json',
      );
      final statsMap = jsonDecode(statsJson) as Map<String, dynamic>;
      final normStats = NormStats(
        mean: (statsMap['mean'] as num).toDouble(),
        std: (statsMap['std'] as num).toDouble(),
      );

      final audio = AudioCaptureService();
      // Build synchronously — O(64×513) ≈ microseconds, no need for isolate.
      final melSpec = MelSpectrogramExtractor(normStats: normStats);
      final kws = OnnxKWSInterpreter();
      var kwsReady = false;
      try {
        await kws.load();
        kwsReady = true;
      } catch (e) {
        debugPrint('[KWS] Model load failed (fallback mode): $e');
        initError = 'KWS model no disponible en emulador x86';
      }

      final lm = LiteRTLMService();
      try {
        // Timeout to prevent hang if MethodChannel never responds.
        await lm.init().timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('[LiteRTLM] Init failed (fallback mode): $e');
      }

      if (kwsReady) {
        _listenUseCase = ListenAndClassifyUseCase(
          audio: audio,
          melSpec: melSpec,
          kws: kws,
        );
      }
      _lmService = lm;
    } catch (e) {
      debugPrint('[Init] Fatal error: $e');
      initError = 'Error de inicialización: $e';
    }
    debugPrint('[Init] background init complete');
    notifyListeners();
  }

  Future<void> startListening() async {
    if (isListening) return;
    if (_listenUseCase == null) {
      initError = 'KWS no esta disponible en este entorno';
      notifyListeners();
      return;
    }

    try {
      await _listenUseCase!.start();
      await _sub?.cancel();
      _sub = _listenUseCase!.commandStream.listen(_onCommand);
      isListening = true;
      initError = null;
    } catch (e) {
      debugPrint('[Audio] Start failed: $e');
      isListening = false;
      initError = 'No se pudo iniciar el microfono: $e';
    }
    notifyListeners();
  }

  Future<void> stopListening() async {
    await _listenUseCase?.stop();
    await _sub?.cancel();
    isListening = false;
    notifyListeners();
  }

  Future<void> _onCommand(VoiceCommand command) async {
    lastCommand = command;
    final action =
        await (_lmService?.interpretKeyword(command) ??
            Future.value(ExecuteCommandUseCase.resolve(command)));
    final screenAtCommand = currentScreen;
    homeState = _applyAction(homeState, action, screenAtCommand);
    _handleScreenNavigation(action, command.label, screenAtCommand);
    notifyListeners();
  }

  /// Wraps ExecuteCommandUseCase.apply with screen-aware overrides.
  SmartHomeState _applyAction(
    SmartHomeState state,
    SmartHomeAction action,
    AppScreen screen,
  ) {
    if (action.type == ActionType.navigate && screen == AppScreen.dashboard) {
      return _executeUseCase.apply(state, action);
    }

    if (action.type == ActionType.navigate && screen == AppScreen.routines) {
      final dir = action.direction ?? 'down';
      int next = state.routineFocusIndex;
      final count = state.routines.length;
      if (dir == 'up') {
        next = (next - 1 + count) % count;
      } else if (dir == 'down') {
        next = (next + 1) % count;
      }
      return state.copyWith(routineFocusIndex: next);
    }

    if (action.type == ActionType.toggleDevice && screen == AppScreen.device) {
      return _executeUseCase.apply(state, action);
    }

    // go on device screen = turn on
    if (action.type == ActionType.controlRoutine &&
        screen == AppScreen.device) {
      return _executeUseCase.apply(
        state,
        const SmartHomeAction(type: ActionType.toggleDevice, state: 'on'),
      );
    }

    if (action.type == ActionType.controlRoutine &&
        screen == AppScreen.routines) {
      final idx = state.routineFocusIndex;
      final updated = List<bool>.from(state.routineRunning);
      updated[idx] = action.state == 'go';
      return state.copyWith(routineRunning: updated);
    }

    return state;
  }

  void _handleScreenNavigation(
    SmartHomeAction action,
    String keyword,
    AppScreen screen,
  ) {
    // confirm: yes/no
    if (action.type == ActionType.confirm) {
      if (keyword == 'yes' && screen == AppScreen.dashboard) {
        final idx = homeState.focusIndex;
        currentScreen = idx < homeState.devices.length
            ? AppScreen.device
            : AppScreen.routines;
      } else if (keyword == 'yes' && screen == AppScreen.confirmation) {
        currentScreen = AppScreen.dashboard;
      } else if (keyword == 'no' && screen != AppScreen.dashboard) {
        currentScreen = AppScreen.dashboard;
      }
      return;
    }

    // go on dashboard = enter focused item (same as yes)
    if (action.type == ActionType.controlRoutine &&
        keyword == 'go' &&
        screen == AppScreen.dashboard) {
      final idx = homeState.focusIndex;
      currentScreen = idx < homeState.devices.length
          ? AppScreen.device
          : AppScreen.routines;
      return;
    }

    // stop anywhere (except dashboard) = go back
    if (action.type == ActionType.controlRoutine &&
        keyword == 'stop' &&
        screen != AppScreen.dashboard &&
        screen != AppScreen.routines) {
      currentScreen = AppScreen.dashboard;
      return;
    }

    // left = go back
    if (action.type == ActionType.navigate &&
        action.direction == 'left' &&
        screen != AppScreen.dashboard) {
      currentScreen = AppScreen.dashboard;
    }
  }

  void navigateTo(AppScreen screen) {
    currentScreen = screen;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _listenUseCase?.dispose();
    _lmService?.dispose();
    super.dispose();
  }
}
