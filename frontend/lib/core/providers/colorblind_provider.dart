/// ColorblindModeNotifier — persists the colorblind-mode toggle.
///
/// Reads the stored value from [SharedPreferences] on first build,
/// defaulting to false. Toggle with [toggle()].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kColorblindKey = 'colorblind_mode';

class ColorblindNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Kick off async load — state will update once prefs are read.
    // Starting value is false (normal mode) to avoid a flash.
    Future.microtask(_loadFromPrefs);
    return false;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_kColorblindKey) ?? false;
  }

  /// Toggle colorblind mode and persist the new value.
  Future<void> toggle() async {
    final newValue = !state;
    state = newValue;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kColorblindKey, newValue);
  }
}

final colorblindProvider =
    NotifierProvider<ColorblindNotifier, bool>(ColorblindNotifier.new);
