// Application layer — use case: execute a Smart Home action given a keyword
import '../../domain/entities/voice_command.dart';
import '../../domain/entities/smart_home_state.dart';

/// Resolves a voice command into a SmartHomeAction using a static keyword→action map.
/// The LiteRT-LM NLU layer (LiteRTLMService) can replace this at runtime.
enum ActionType { navigate, toggleDevice, controlRoutine, confirm, none }

class SmartHomeAction {
  final ActionType type;
  final String? direction;
  final String? device;
  final String? state;
  final String? routine;
  final String? answer;

  const SmartHomeAction({
    required this.type,
    this.direction,
    this.device,
    this.state,
    this.routine,
    this.answer,
  });

  static const SmartHomeAction none = SmartHomeAction(type: ActionType.none);
}

class ExecuteCommandUseCase {
  static SmartHomeAction resolve(VoiceCommand command) {
    switch (command.label) {
      case 'up':
        return const SmartHomeAction(
          type: ActionType.navigate,
          direction: 'up',
        );
      case 'down':
        return const SmartHomeAction(
          type: ActionType.navigate,
          direction: 'down',
        );
      case 'left':
        return const SmartHomeAction(
          type: ActionType.navigate,
          direction: 'left',
        );
      case 'right':
        return const SmartHomeAction(
          type: ActionType.navigate,
          direction: 'right',
        );
      case 'on':
        return const SmartHomeAction(
          type: ActionType.toggleDevice,
          state: 'on',
        );
      case 'off':
        return const SmartHomeAction(
          type: ActionType.toggleDevice,
          state: 'off',
        );
      case 'go':
        return const SmartHomeAction(
          type: ActionType.controlRoutine,
          state: 'go',
        );
      case 'stop':
        return const SmartHomeAction(
          type: ActionType.controlRoutine,
          state: 'stop',
        );
      case 'yes':
        return const SmartHomeAction(type: ActionType.confirm, answer: 'yes');
      case 'no':
        return const SmartHomeAction(type: ActionType.confirm, answer: 'no');
      default:
        return SmartHomeAction.none;
    }
  }

  SmartHomeState apply(SmartHomeState state, SmartHomeAction action) {
    switch (action.type) {
      case ActionType.navigate:
        return _handleNavigation(state, action.direction ?? 'down');
      case ActionType.toggleDevice:
        return _handleToggle(state, action.state ?? 'off');
      default:
        return state;
    }
  }

  SmartHomeState _handleNavigation(SmartHomeState state, String direction) {
    int next = state.focusIndex;
    final count = state.devices.length + 1; // devices + routines card
    const cols = 2; // dashboard grid has 2 columns
    switch (direction) {
      case 'up':
        next = (next - cols + count) % count;
        break;
      case 'down':
        next = (next + cols) % count;
        break;
      case 'left':
        next = (next - 1 + count) % count;
        break;
      case 'right':
        next = (next + 1) % count;
        break;
    }
    return state.copyWith(focusIndex: next);
  }

  SmartHomeState _handleToggle(SmartHomeState state, String newState) {
    final idx = state.focusIndex;
    if (idx >= state.devices.length) return state;
    final updated = List<DeviceStatus>.from(state.devices);
    updated[idx] = updated[idx].copyWith(
      state: newState == 'on' ? DeviceState.on : DeviceState.off,
    );
    return state.copyWith(devices: updated);
  }
}
