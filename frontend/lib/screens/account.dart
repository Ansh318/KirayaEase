import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final firstName = prefs.getString('onboarding_first_name') ?? 'John';
    final lastName = prefs.getString('onboarding_last_name') ?? 'Doe';
    final email = prefs.getString('user_email') ?? 'john.doe@example.com';
    final rawPhone = prefs.getString('onboarding_phone') ?? '';
    final role = (prefs.getString('user_role') ?? 'tenant').toLowerCase();

    user = widget.initial ??
        UserAccount(
          firstName: firstName,
          lastName: lastName,
          email: email,
          phone: _formatPhone(rawPhone),
          idNumber: 'ABCDE1234F', // hardcoded as requested
          accountStatus: 'Verified', // hardcoded as requested
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
                const SizedBox(height: 10),
                _infoTile(
                  icon: Icons.verified_user_outlined,
                  label: 'Aadhaar / PAN',
                  value: getMaskedId(user.idNumber),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0x14000000)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: _statusColor(user.accountStatus),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Account status',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B6B6B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        user.accountStatus,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

  // determine color for status dot
  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('verify') || s.contains('active')) return const Color(0xFF21A07A);
    if (s.contains('pending')) return Colors.orange;
    if (s.contains('blocked') || s.contains('suspended')) return Colors.red;
    return Colors.grey;
  }
}
