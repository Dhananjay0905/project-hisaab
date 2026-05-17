/// Profile & Settings page.
///
/// Allows the user to:
///   • Edit their display name (inline)
///   • Request an email change (2-step verification via email)
///   • Change their password (bottom sheet)
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failures.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  // ── Name editing ──────────────────────────────────────────────────────────
  bool _editingName = false;
  late TextEditingController _nameCtrl;
  final _nameFocus = FocusNode();
  bool _savingName = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameCtrl = TextEditingController(text: user?.name ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : const Color(0xFF3861FB),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  String _failureMessage(Object failure) {
    if (failure is ValidationFailure) return failure.message;
    if (failure is ServerFailure) return failure.message;
    if (failure is NetworkFailure) return 'No internet connection.';
    return 'Something went wrong. Please try again.';
  }

  // ── Name save ─────────────────────────────────────────────────────────────

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || name.length < 2) {
      _showSnack('Name must be at least 2 characters.', isError: true);
      return;
    }
    setState(() => _savingName = true);
    try {
      await ref.read(authNotifierProvider.notifier).updateName(name);
      setState(() => _editingName = false);
      _showSnack('Name updated successfully!');
    } catch (e) {
      _showSnack(_failureMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  // ── Email change sheet ────────────────────────────────────────────────────

  void _openEmailChangeSheet() {
    final emailCtrl = TextEditingController();
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => _buildSheet(
          title: 'Change Email',
          icon: Icons.email_rounded,
          children: [
            const Text(
              'Enter your new email address. We\'ll send a confirmation link to your '
              'current email first, then a verification link to the new one.',
              style: TextStyle(fontSize: 14, color: Color(0xFF595C60), height: 1.5),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: emailCtrl,
              label: 'New email address',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            _buildPrimaryButton(
              label: 'Send Confirmation',
              loading: loading,
              onTap: () async {
                final newEmail = emailCtrl.text.trim();
                if (newEmail.isEmpty || !newEmail.contains('@')) {
                  _showSnack('Please enter a valid email.', isError: true);
                  return;
                }
                setSheetState(() => loading = true);
                try {
                  await ref
                      .read(authNotifierProvider.notifier)
                      .requestEmailChange(newEmail);
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showSnack(
                    'Check your current email to confirm the change.',
                  );
                } catch (e) {
                  _showSnack(_failureMessage(e), isError: true);
                } finally {
                  if (ctx.mounted) setSheetState(() => loading = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Password change sheet ─────────────────────────────────────────────────

  void _openPasswordSheet() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool loading = false;
    bool showCurrent = false;
    bool showNew = false;
    bool showConfirm = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => _buildSheet(
          title: 'Change Password',
          icon: Icons.lock_rounded,
          children: [
            _buildTextField(
              controller: currentCtrl,
              label: 'Current password',
              obscure: !showCurrent,
              suffix: IconButton(
                icon: Icon(showCurrent ? Icons.visibility_off : Icons.visibility,
                    size: 20, color: const Color(0xFF8E8E93)),
                onPressed: () => setSheetState(() => showCurrent = !showCurrent),
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: newCtrl,
              label: 'New password (min. 8 chars)',
              obscure: !showNew,
              suffix: IconButton(
                icon: Icon(showNew ? Icons.visibility_off : Icons.visibility,
                    size: 20, color: const Color(0xFF8E8E93)),
                onPressed: () => setSheetState(() => showNew = !showNew),
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: confirmCtrl,
              label: 'Confirm new password',
              obscure: !showConfirm,
              suffix: IconButton(
                icon: Icon(showConfirm ? Icons.visibility_off : Icons.visibility,
                    size: 20, color: const Color(0xFF8E8E93)),
                onPressed: () => setSheetState(() => showConfirm = !showConfirm),
              ),
            ),
            const SizedBox(height: 24),
            _buildPrimaryButton(
              label: 'Update Password',
              loading: loading,
              onTap: () async {
                final current = currentCtrl.text;
                final newPass = newCtrl.text;
                final confirm = confirmCtrl.text;

                if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
                  _showSnack('Please fill in all fields.', isError: true);
                  return;
                }
                if (newPass.length < 8) {
                  _showSnack('Password must be at least 8 characters.', isError: true);
                  return;
                }
                if (newPass != confirm) {
                  _showSnack('New passwords do not match.', isError: true);
                  return;
                }

                setSheetState(() => loading = true);
                try {
                  await ref.read(authNotifierProvider.notifier).changePassword(
                        currentPassword: current,
                        newPassword: newPass,
                      );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _showSnack('Password changed successfully!');
                } catch (e) {
                  _showSnack(_failureMessage(e), isError: true);
                } finally {
                  if (ctx.mounted) setSheetState(() => loading = false);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final initials = _initials(user?.name ?? '?');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Avatar card ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3861FB), Color(0xFF849AFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                // Avatar circle
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? '',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.email ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (user?.createdAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Member since ${_formatJoined(user!.createdAt)}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Account info section ─────────────────────────────────────────────
          _sectionLabel('ACCOUNT INFO', isDark),
          const SizedBox(height: 8),
          _card(
            isDark: isDark,
            children: [
              // Name row
              _editingName
                  ? _nameEditRow()
                  : _settingsTile(
                      icon: Icons.person_rounded,
                      label: 'Name',
                      value: user?.name ?? '',
                      onTap: () {
                        setState(() {
                          _editingName = true;
                          _nameCtrl.text = user?.name ?? '';
                        });
                        Future.delayed(const Duration(milliseconds: 80), () {
                          _nameFocus.requestFocus();
                        });
                      },
                    ),
              _divider(isDark),
              // Email row
              _settingsTile(
                icon: Icons.email_rounded,
                label: 'Email',
                value: user?.email ?? '',
                onTap: _openEmailChangeSheet,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Security section ─────────────────────────────────────────────────
          _sectionLabel('SECURITY', isDark),
          const SizedBox(height: 8),
          _card(
            isDark: isDark,
            children: [
              _settingsTile(
                icon: Icons.lock_rounded,
                label: 'Change Password',
                onTap: _openPasswordSheet,
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _nameEditRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF3861FB).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.person_rounded, size: 18, color: Color(0xFF3861FB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              focusNode: _nameFocus,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Your name',
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _saveName(),
            ),
          ),
          const SizedBox(width: 8),
          if (_savingName)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            GestureDetector(
              onTap: () => setState(() => _editingName = false),
              child: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF8E8E93)),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _saveName,
              child: const Icon(Icons.check_rounded, size: 20, color: Color(0xFF3861FB)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _settingsTile({
    required IconData icon,
    required String label,
    String? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF3861FB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF3861FB)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (value != null && value.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF8E8E93),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF8E8E93)),
          ],
        ),
      ),
    );
  }

  Widget _card({required bool isDark, required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: children,
        ),
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
        height: 1,
        indent: 64,
        endIndent: 16,
        color: isDark ? Colors.white10 : const Color(0xFFE6E8EE),
      );

  Widget _sectionLabel(String label, bool isDark) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: isDark ? Colors.white38 : const Color(0xFF8E8E93),
          ),
        ),
      );

  // ── Bottom sheet builder ──────────────────────────────────────────────────

  Widget _buildSheet({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFDDE0E5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF3861FB).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF3861FB), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscure = false,
    Widget? suffix,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF5F6FB),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF3861FB), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          disabledBackgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
      ),
    );
  }

  // ── Formatters ────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _formatJoined(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}
