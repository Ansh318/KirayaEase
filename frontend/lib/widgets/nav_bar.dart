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
                      cacheWidth: 144,
                      cacheHeight: 144,
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                    color: Colors.white,
                    elevation: 8,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: Colors.black26,
                    padding: EdgeInsets.zero,
                    onSelected: (route) {
                      Navigator.pushNamed(context, route);
                    },
                    itemBuilder: (context) {
                      return [
                        _popupItem("Home", '/'),
                        _popupItem("Mission", '/mission'),
                        _popupItem("Landlords", '/landlord-info'),
                        _popupItem("Pricing", '/pricing'),
                        _popupItem("About Me", '/about-us'),
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
      _navItem(context, "Mission", '/mission'),
      _navItem(context, "Landlords", '/landlord-info'),
      _navItem(context, "Pricing", '/pricing'),
      _navItem(context, "About Me", '/about-us'),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: SizedBox(
        width: 220,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
