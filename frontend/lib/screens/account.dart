import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Simple user account model
class UserAccount {
  String firstName;
  String lastName;
  String email;
  String phone;
  String idNumber; // Aadhaar or PAN (store full value here; we'll mask in UI)
  String accountStatus; // e.g., "Verified", "Pending"

  UserAccount({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.idNumber,
    required this.accountStatus,
  });
}

class AccountPage extends StatefulWidget {
  final UserAccount? initial;

  /// You can pass a pre-filled UserAccount, otherwise example data is used.
  const AccountPage({Key? key, this.initial}) : super(key: key);

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late UserAccount user;
  bool _loading = true;
  String _userRole = 'tenant';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    // Local fallback values from onboarding / login
    String firstName = prefs.getString('onboarding_first_name') ?? 'John';
    String lastName = prefs.getString('onboarding_last_name') ?? 'Doe';
    final email = prefs.getString('user_email') ?? 'john.doe@example.com';
    final rawPhone = prefs.getString('onboarding_phone') ?? '';
    String role = (prefs.getString('user_role') ?? 'tenant').toLowerCase();
    String? aadhaar;
    String? pan;

    final sessionId = prefs.getString('session_id');

    // Try to hydrate profile from backend if we have a valid session.
    if (sessionId != null && sessionId.trim().isNotEmpty) {
      try {
        final response = await http.get(
          Uri.parse(ApiConfig.userProfileEndpoint),
          headers: {
            'Authorization': 'Bearer $sessionId',
          },
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data =
              jsonDecode(utf8.decode(response.bodyBytes));

          final apiFirstName = (data['first_name'] ?? '').toString().trim();
          final apiLastName = (data['last_name'] ?? '').toString().trim();
          if (apiFirstName.isNotEmpty) {
            firstName = apiFirstName;
          }
          if (apiLastName.isNotEmpty) {
            lastName = apiLastName;
          }

          final aadhaarValue = data['aadhaar'];
          final panValue = data['pan'];
          aadhaar =
              aadhaarValue != null ? aadhaarValue.toString().trim() : null;
          pan = panValue != null ? panValue.toString().trim() : null;

          final apiRole = (data['role'] ?? '').toString().toLowerCase();
          if (apiRole.isNotEmpty) {
            role = apiRole;
            await prefs.setString('user_role', role);
          }
        }
      } catch (_) {
        // Ignore network / parsing errors and fall back to local data.
      }
    }

    final String resolvedIdNumber;
    if (pan != null && pan.isNotEmpty) {
      resolvedIdNumber = pan;
    } else if (aadhaar != null && aadhaar.isNotEmpty) {
      resolvedIdNumber = aadhaar;
    } else {
      resolvedIdNumber = '';
    }

    final String resolvedStatus;
    if (resolvedIdNumber.isNotEmpty) {
      resolvedStatus = 'Verified';
    } else {
      resolvedStatus = 'Pending verification';
    }

    user = widget.initial ??
        UserAccount(
          firstName: firstName,
          lastName: lastName,
          email: email,
          phone: _formatPhone(rawPhone),
          idNumber: resolvedIdNumber,
          accountStatus: resolvedStatus,
        );

    if (!mounted) return;
    setState(() {
      _userRole = role == 'landlord' ? 'landlord' : 'tenant';
      _loading = false;
    });
  }

  String _formatPhone(String digits) {
    final onlyDigits = digits.replaceAll(RegExp(r'\D'), '');
    if (onlyDigits.length == 10) {
      return '+91 ${onlyDigits.substring(0, 5)} ${onlyDigits.substring(5)}';
    }
    if (onlyDigits.isEmpty) return '+91 -';
    return '+91 $onlyDigits';
  }

  String getMaskedId(String id) {
    if (id.isEmpty) return '';
    final visible = id.length <= 4 ? id : id.substring(id.length - 4);
    return '${'*' * (id.length - visible.length)}$visible';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF9),
      appBar: AppBar(
        foregroundColor: Colors.black,
        backgroundColor: const Color(0xFFF4FAF9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: false,
        title: const Text(
          'Account',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 30,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDFFBF7), Color(0xFFF2FFFD)],
                    ),
                    border: Border.all(color: const Color(0x2200C6A6)),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 24,
                        backgroundColor: Color(0xFF9BE7DB),
                        child: Icon(Icons.person, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${user.firstName} ${user.lastName}'.trim(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _userRole == 'landlord' ? 'Landlord' : 'Tenant',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF167D60),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _infoTile(
                  icon: Icons.badge_outlined,
                  label: 'First name',
                  value: user.firstName,
                ),
                const SizedBox(height: 10),
                _infoTile(
                  icon: Icons.badge_outlined,
                  label: 'Last name',
                  value: user.lastName,
                ),
                const SizedBox(height: 10),
                _infoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user.email,
                ),
                const SizedBox(height: 10),
                _infoTile(
                  icon: Icons.phone_iphone_outlined,
                  label: 'Phone',
                  value: user.phone,
                ),
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _confirmDeleteAccount(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red[700],
                    ),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text(
                      'Delete account',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete account?'),
          content: const Text(
            'This will permanently delete your KirayaEase account and all your '
            'data (properties, leases, payments). You will be signed out and '
            'returned to the home screen. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[700],
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _deleteAccount(context);
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');

    if (sessionId == null || sessionId.trim().isEmpty) {
      await _clearLocalDataAndGoHome(context);
      return;
    }

    try {
      final response = await http.delete(
        Uri.parse(ApiConfig.deleteAccountEndpoint),
        headers: {'Authorization': 'Bearer $sessionId'},
      );

      if (response.statusCode == 200) {
        await _clearLocalDataAndGoHome(context);
        if (!context.mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Account deleted. You have been signed out.'),
          ),
        );
      } else {
        if (!context.mounted) return;
        final msg = response.statusCode == 401
            ? 'Session expired. You have been signed out.'
            : 'Could not delete account. Please try again.';
        messenger.showSnackBar(SnackBar(content: Text(msg)));
        if (response.statusCode == 401) {
          await _clearLocalDataAndGoHome(context);
        }
      }
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Could not delete account. Please try again.'),
        ),
      );
    }
  }

  Future<void> _clearLocalDataAndGoHome(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_id');
    await prefs.remove('session_token');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    await prefs.remove('onboarding_first_name');
    await prefs.remove('onboarding_last_name');
    await prefs.remove('onboarding_phone');
    await prefs.remove('active_scope');
    await prefs.remove('active_property_id');
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/',
      (route) => false,
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x14000000)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF167D60), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B6B6B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
