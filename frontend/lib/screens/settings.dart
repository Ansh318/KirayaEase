import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const _ink = Color(0xFF1C1C1E);
  static const _sub = Color(0xFF6F6F73);
  static const _divider = Color(0xFFE8E8EB);
  static const _appShareUrl = 'https://kirayaease.com';

  Future<void> _shareKirayaEase(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    const shareText =
        'Check out KirayaEase for smarter rent management: $_appShareUrl';

    await Clipboard.setData(const ClipboardData(text: _appShareUrl));
    await Share.share(shareText);

    messenger.showSnackBar(
      const SnackBar(content: Text('App link copied. Share sheet opened.')),
    );
  }

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
                onTap: () => Navigator.pushNamed(context, '/account')),
            const _Divider(),
            const SizedBox(height: 28),

            // ===== Rent =====
            const _SectionHeader('Rent'),
            const _Divider(),
            _Row.icon(
                icon: Icons.vpn_key_outlined,
                title: 'Properties',
                onTap: () => Navigator.pushNamed(context, '/lease-manager')),
            const _Divider(),
            _Row.icon(
              icon: Icons.payments_outlined,
              title: 'Payments',
              onTap: () => Navigator.pushNamed(context, '/payments'),
            ),
            const _Divider(),
            // Rent reporting – for later
            // _Row.icon(
            //   icon: Icons.bar_chart_rounded,
            //   title: 'Rent reporting',
            //   onTap: () => Navigator.pushNamed(context, '/rent-reporting'),
            // ),
            // const _Divider(),
            const SizedBox(height: 28),

            // ===== Other =====
            const _SectionHeader('Support & App Info'),
            const _Divider(),
            _Row.icon(
              icon: Icons.help_outline_rounded,
              title: 'Help center',
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
              onTap: () => _shareKirayaEase(context),
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
