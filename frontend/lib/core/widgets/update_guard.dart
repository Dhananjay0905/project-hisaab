/// UpdateGuard — wraps the app body and shows update dialogs when needed.
///
/// Hard block  (installed < minVersion):
///   Non-dismissible full-screen overlay. The user cannot interact with the
///   app at all until they get the new APK.
///
/// Soft update (minVersion <= installed < latestVersion):
///   Dismissible dialog shown once per latestVersion value.
///   - "Remind me later" → dismissed for this session only.
///   - "Don't show again" → stores the dismissed version in SharedPreferences;
///     dialog won't appear again unless the backend bumps latestVersion.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_config_provider.dart';

// SharedPreferences key prefix for dismissed soft-update versions.
const _kDismissedVersionKey = 'dismissed_update_version';

class UpdateGuard extends ConsumerStatefulWidget {
  const UpdateGuard({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<UpdateGuard> createState() => _UpdateGuardState();
}

class _UpdateGuardState extends ConsumerState<UpdateGuard> {
  bool _softDialogShown = false;

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(appConfigProvider);

    return configAsync.when(
      loading: () => widget.child,
      error: (_, __) => widget.child, // Fail open
      data: (status) {
        if (status.isHardBlock) {
          return Stack(
            children: [
              widget.child,
              _HardBlockOverlay(message: status.criticalMessage),
            ],
          );
        }

        if (status.isSoftUpdate && !_softDialogShown) {
          _maybeShowSoftDialog(status);
        }

        return widget.child;
      },
    );
  }

  Future<void> _maybeShowSoftDialog(AppUpdateStatus status) async {
    // Check if user already dismissed this specific latestVersion.
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getString(_kDismissedVersionKey);
    if (dismissed == status.latestVersion) return;

    if (!mounted) return;
    setState(() => _softDialogShown = true);

    // ignore: use_build_context_synchronously
    // mounted is checked immediately above; context is the State's own context.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SoftUpdateDialog(
        status: status,
        onDismissForever: () async {
          final p = await SharedPreferences.getInstance();
          await p.setString(_kDismissedVersionKey, status.latestVersion);
        },
      ),
    );
  }
}

// ─── Hard block overlay ───────────────────────────────────────────────────────

class _HardBlockOverlay extends StatelessWidget {
  const _HardBlockOverlay({required this.message});
  final String message;

  Future<void> _openEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'projecthisaab.app@gmail.com',
      queryParameters: {'subject': 'Hisaab App Update Request'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: cs.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.system_update_rounded,
                      size: 40, color: cs.primary),
                ),
                const SizedBox(height: 28),

                // Title
                Text(
                  'Update Required',
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Message from backend
                Text(
                  message.isNotEmpty
                      ? message
                      : 'This version of Hisaab is no longer supported. Please update to continue.',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Contact info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'To get the latest version:',
                        style: tt.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'If you know the developer, message him directly.\nOr email us at:',
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _openEmail,
                        child: Text(
                          'projecthisaab.app@gmail.com',
                          style: tt.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Email button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _openEmail,
                    icon: const Icon(Icons.mail_outline_rounded),
                    label: const Text('Email for Update'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Soft update dialog ───────────────────────────────────────────────────────

class _SoftUpdateDialog extends StatelessWidget {
  const _SoftUpdateDialog({
    required this.status,
    required this.onDismissForever,
  });

  final AppUpdateStatus status;
  final VoidCallback onDismissForever;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: cs.secondaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.new_releases_outlined,
            size: 28, color: cs.secondary),
      ),
      title: Text(
        'Update Available',
        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      ),
      content: Text(
        status.softMessage.isNotEmpty
            ? status.softMessage
            : 'A new version of Hisaab is available.',
        style: tt.bodyMedium?.copyWith(
          color: cs.onSurfaceVariant,
          height: 1.5,
        ),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      actions: [
        // Don't show again
        TextButton(
          onPressed: () {
            onDismissForever();
            Navigator.of(context).pop();
          },
          child: Text(
            "Don't show again",
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 8),
        // Remind later
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text('Remind me later'),
        ),
      ],
    );
  }
}
