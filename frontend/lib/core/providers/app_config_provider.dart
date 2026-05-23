/// App config provider — fetches version + update info from the backend.
///
/// Compares [kAppVersion] (hardcoded in app_version.dart) against the backend's
/// [minVersion] and [latestVersion] to determine which (if any) update dialog
/// to show.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../constants/app_version.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

/// Describes the update status of the currently installed APK.
class AppUpdateStatus {
  const AppUpdateStatus({
    required this.isHardBlock,
    required this.isSoftUpdate,
    required this.latestVersion,
    required this.criticalMessage,
    required this.softMessage,
  });

  /// True when installed version < minVersion — user MUST update to continue.
  final bool isHardBlock;

  /// True when installed version < latestVersion but >= minVersion —
  /// user can still use the app but there's a newer version available.
  final bool isSoftUpdate;

  /// The backend's latestVersion string — used as the SharedPreferences key
  /// for "don't show again" dismissal.
  final String latestVersion;

  /// Message shown in the hard-block dialog.
  final String criticalMessage;

  /// Message shown in the soft-update dialog.
  final String softMessage;

  /// No update needed — app is up to date.
  static const none = AppUpdateStatus(
    isHardBlock: false,
    isSoftUpdate: false,
    latestVersion: kAppVersion,
    criticalMessage: '',
    softMessage: '',
  );
}

// ─── Semver comparison ────────────────────────────────────────────────────────

/// Parses a semver string (e.g. "1.2.3") into a comparable list of ints.
/// Returns [0, 0, 0] on parse failure so the check fails open.
List<int> _parseVersion(String v) {
  try {
    final parts = v.trim().split('.').map(int.parse).toList();
    while (parts.length < 3) { parts.add(0); }
    return parts;
  } catch (_) {
    return [0, 0, 0];
  }
}

/// Returns negative if [a] < [b], 0 if equal, positive if [a] > [b].
int _compareVersions(String a, String b) {
  final av = _parseVersion(a);
  final bv = _parseVersion(b);
  for (var i = 0; i < 3; i++) {
    final diff = av[i] - bv[i];
    if (diff != 0) return diff;
  }
  return 0;
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final appConfigProvider = FutureProvider<AppUpdateStatus>((ref) async {
  try {
    final response = await ApiClient.instance
        .get<Map<String, dynamic>>(ApiEndpoints.appConfig);
    final data = response.data!['data'] as Map<String, dynamic>;

    final minVersion = data['minVersion'] as String? ?? '0.0.0';
    final latestVersion = data['latestVersion'] as String? ?? '0.0.0';
    final criticalMessage = data['criticalUpdateMessage'] as String? ?? '';
    final softMessage = data['softUpdateMessage'] as String? ?? '';

    final isHardBlock = _compareVersions(kAppVersion, minVersion) < 0;
    final isSoftUpdate = !isHardBlock &&
        _compareVersions(kAppVersion, latestVersion) < 0;

    return AppUpdateStatus(
      isHardBlock: isHardBlock,
      isSoftUpdate: isSoftUpdate,
      latestVersion: latestVersion,
      criticalMessage: criticalMessage,
      softMessage: softMessage,
    );
  } catch (_) {
    // Fail open — if the config endpoint is unreachable, don't block the user.
    return AppUpdateStatus.none;
  }
});
