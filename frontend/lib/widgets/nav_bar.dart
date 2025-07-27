import 'dart:ui';
import 'package:flutter/material.dart';

class NavBar extends StatelessWidget {
  const NavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 700;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 🔷 Logo and App Name
                Column(
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      width: 48,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'KirayaEase',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // 💻 Full nav on wide screens
                if (!isMobile)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(40),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: _navItems(context),
                        ),
                      ),
                    ),
                  ),

                // 📱 Hamburger menu on mobile
                if (isMobile)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.menu, color: Colors.black87),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (route) {
                      Navigator.pushNamed(context, route);
                    },
                    itemBuilder: (context) {
                      return [
                        _popupItem("Home", '/'),
                        _popupItem("Mission", '/'),
                        _popupItem("Landlords", '/'),
                        _popupItem("Tenants", '/'),
                        _popupItem("Technology", '/'),
                        _popupItem("Pricing", '/'),
                        _popupItem("Learn", '/'),
                        _popupItem("About", '/'),
                      ];
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _navItems(BuildContext context) {
    return [
      _navItem(context, "Home", '/'),
      _navItem(context, "Mission", '/'),
      _navItem(context, "Landlords", '/'),
      _navItem(context, "Tenants", '/'),
      _navItem(context, "Technology", '/'),
      _navItem(context, "Pricing", '/'),
      _navItem(context, "Learn", '/'),
      _navItem(context, "About", '/'),
    ];
  }

  Widget _navItem(BuildContext context, String title, String route) {
    return TextButton(
      onPressed: () => Navigator.pushNamed(context, route),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  PopupMenuItem<String> _popupItem(String title, String route) {
    return PopupMenuItem<String>(
      value: route,
      child: Text(
        title,
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
