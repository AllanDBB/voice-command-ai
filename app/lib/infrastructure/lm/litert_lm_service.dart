// Infrastructure — LiteRT-LM NLU service via Android MethodChannel (bonus)
import 'dart:async';
import 'package:flutter/services.dart';
import '../../application/usecases/execute_command_usecase.dart';
import '../../domain/entities/voice_command.dart';

class LiteRTLMService {
  static const MethodChannel _channel = MethodChannel('litert_lm');
  static const Duration _timeout = Duration(seconds: 3);

  bool _available = false;

  Future<void> init() async {
    try {
      await _channel.invokeMethod<void>('init');
      _available = true;
    } on PlatformException {
      _available = false;
    }
  }

  /// Interprets a detected keyword using LiteRT-LM Tool Use.
  /// Falls back to static keyword→action map if LM is unavailable or too slow.
  Future<SmartHomeAction> interpretKeyword(VoiceCommand command) async {
    if (!_available) return _staticFallback(command);

    try {
      final result = await _channel
          .invokeMethod<Map<Object?, Object?>>('interpret', {
            'keyword': command.label,
          })
          .timeout(_timeout);

      if (result == null) return _staticFallback(command);
      return _parseToolCall(result);
    } on TimeoutException {
      return _staticFallback(command);
    } on PlatformException {
      return _staticFallback(command);
    }
  }

  SmartHomeAction _parseToolCall(Map<Object?, Object?> result) {
    final tool = result['tool'] as String? ?? '';
    switch (tool) {
      case 'navigate':
        return SmartHomeAction(
          type: ActionType.navigate,
          direction: result['direction'] as String?,
        );
      case 'toggleDevice':
        return SmartHomeAction(
          type: ActionType.toggleDevice,
          device: result['device'] as String?,
          state: result['state'] as String?,
        );
      case 'controlRoutine':
        return SmartHomeAction(
          type: ActionType.controlRoutine,
          routine: result['routine'] as String?,
          state: result['action'] as String? ?? result['state'] as String?,
        );
      case 'confirm':
        return SmartHomeAction(
          type: ActionType.confirm,
          answer: result['answer'] as String?,
        );
      default:
        return SmartHomeAction.none;
    }
  }

  SmartHomeAction _staticFallback(VoiceCommand command) =>
      ExecuteCommandUseCase.resolve(command);

  Future<void> dispose() async {
    if (_available) {
      try {
        await _channel.invokeMethod<void>('dispose');
      } on PlatformException {
        // ignore
      }
    }
  }
}
