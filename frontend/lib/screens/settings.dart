import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _ink = Color(0xFF1C1C1E);
  static const _sub = Color(0xFF6F6F73);
  static const _divider = Color(0xFFE8E8EB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 12),

            // Back button + Title
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: _ink),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: _ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ===== General =====
            const _SectionHeader('General'),
            const _Divider(),
            _Row.icon(
              icon: Icons.person_outline_rounded,
              title: 'Account',
              onTap: () {},
            ),
            const _Divider(),
            _Row.icon(
              icon: Icons.credit_card_outlined,
              title: 'Payment methods',
              onTap: () {},
            ),
            const _Divider(),
            const SizedBox(height: 28),

            // ===== Rent =====
            const _SectionHeader('Rent'),
            const _Divider(),
            const _Row.disabled(
              icon: Icons.vpn_key_outlined,
              title: 'Property',
            ),
            const _Divider(),
            _Row.icon(
              icon: Icons.bar_chart_rounded,
              title: 'Rent reporting',
              onTap: () {},
            ),

            const SizedBox(height: 28),

            // ===== Other =====
            const _SectionHeader('Other'),
            const _Divider(),
            _Row.icon(
              icon: Icons.help_outline_rounded,
              title: 'Help center',
              onTap: () {},
            ),
            const _Divider(),
            _Row.icon(
              icon: Icons.lock_outline_rounded,
              title: 'Privacy',
              onTap: () {},
            ),
            const _Divider(),
            _Row.icon(
              icon: Icons.scale_outlined,
              title: 'Legal agreements',
              onTap: () {},
            ),
            const _Divider(),
            _Row.icon(
              icon: Icons.info_outline_rounded,
              title: 'App info',
              onTap: () {},
            ),
            const _Divider(),
            _Row.icon(
              icon: Icons.star_border_rounded,
              title: 'Rate KirayaEase',
              onTap: () {},
            ),
            const _Divider(),
            _Row.icon(
              icon: Icons.ios_share_rounded,
              title: 'Share KirayaEase',
              onTap: () {},
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 24, 2, 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: SettingsPage._ink,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.75,
      color: SettingsPage._divider,
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool disabled;

  const _Row.icon({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
  }) : disabled = false;

  const _Row.disabled({
    super.key,
    required this.icon,
    required this.title,
  })  : disabled = true,
        trailing = null,
        onTap = null;

  @override
  Widget build(BuildContext context) {
    final chevron = disabled
        ? const SizedBox.shrink()
        : const Icon(Icons.chevron_right, color: SettingsPage._sub);

    return ListTile(
      leading: Icon(
        icon,
        color:
            disabled ? SettingsPage._sub.withOpacity(0.4) : SettingsPage._ink,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 17,
          color:
              disabled ? SettingsPage._sub.withOpacity(0.6) : SettingsPage._ink,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null) trailing!,
          if (trailing != null && !disabled) const SizedBox(width: 8),
          chevron,
        ],
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: disabled ? null : onTap,
      enabled: !disabled,
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: SettingsPage._ink,
        ),
      ),
    );
  }
}
