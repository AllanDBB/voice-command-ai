// Domain entity — smart home state
enum DeviceState { on, off }

class DeviceStatus {
  final String name;
  final String icon;
  final DeviceState state;

  const DeviceStatus({
    required this.name,
    required this.icon,
    required this.state,
  });

  DeviceStatus copyWith({DeviceState? state}) =>
      DeviceStatus(name: name, icon: icon, state: state ?? this.state);
}

class SmartHomeState {
  final List<DeviceStatus> devices;
  final List<String> routines;
  final List<bool> routineRunning;
  final int focusIndex;
  final int routineFocusIndex;

  const SmartHomeState({
    required this.devices,
    required this.routines,
    required this.routineRunning,
    this.focusIndex = 0,
    this.routineFocusIndex = 0,
  });

  static SmartHomeState initial() => const SmartHomeState(
    devices: [
      DeviceStatus(name: 'Luces', icon: '💡', state: DeviceState.off),
      DeviceStatus(name: 'Ventilador', icon: '🌀', state: DeviceState.off),
      DeviceStatus(name: 'TV', icon: '📺', state: DeviceState.off),
    ],
    routines: ['Mañana', 'Noche', 'Cine'],
    routineRunning: [false, false, false],
  );

  SmartHomeState copyWith({
    List<DeviceStatus>? devices,
    List<String>? routines,
    List<bool>? routineRunning,
    int? focusIndex,
    int? routineFocusIndex,
  }) => SmartHomeState(
    devices: devices ?? this.devices,
    routines: routines ?? this.routines,
    routineRunning: routineRunning ?? this.routineRunning,
    focusIndex: focusIndex ?? this.focusIndex,
    routineFocusIndex: routineFocusIndex ?? this.routineFocusIndex,
  );
}
