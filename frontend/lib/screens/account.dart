// lib/account.dart
import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    user = widget.initial ??
        UserAccount(
          firstName: 'John',
          lastName: 'Doe',
          email: 'john.doe@example.com',
          phone: '+1 234 567 8900',
          idNumber:
              '123412341234', // example Aadhaar; could be PAN e.g. ABCDE1234F
          accountStatus: 'Verified',
        );
  }

  // Mask: show only last 4 characters of idNumber, replace rest with '*'
  String getMaskedId(String id) {
    if (id.isEmpty) return '';
    final visible = id.length <= 4 ? id : id.substring(id.length - 4);
    return '${'*' * (id.length - visible.length)}$visible';
  }

  Future<void> _editField({
    required String title,
    required String initialValue,
    required ValueChanged<String> onSave,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? hintText,
    int? maxLength,
  }) async {
    final controller = TextEditingController(text: initialValue);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Edit $title',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                maxLength: maxLength,
                decoration: InputDecoration(
                  hintText: hintText ?? 'Enter $title',
                  border: const OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        final newValue = controller.text.trim();
                        onSave(newValue);
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow({
    required String label,
    required String value,
    VoidCallback? onTap,
    bool showChevron = true,
  }) {
    final labelStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );
    final valueStyle = const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w400,
    );

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: labelStyle),
                    const SizedBox(height: 8),
                    Text(value, style: valueStyle),
                  ],
                ),
              ),
              if (showChevron)
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF9AA0A6),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Divider that matches the thin line style from your screenshots
  Widget _thinDivider() {
    return const Divider(height: 1, thickness: 1, indent: 16, endIndent: 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // keep background white like your screenshots
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        centerTitle: false,
        title: const Text(
          'Account',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
            fontSize: 28,
          ),
        ),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          _infoRow(
            label: 'First name',
            value: user.firstName,
            onTap: () => _editField(
              title: 'First name',
              initialValue: user.firstName,
              onSave: (v) => setState(() => user.firstName = v),
              hintText: 'First name',
            ),
          ),
          _thinDivider(),
          _infoRow(
            label: 'Last name',
            value: user.lastName,
            onTap: () => _editField(
              title: 'Last name',
              initialValue: user.lastName,
              onSave: (v) => setState(() => user.lastName = v),
              hintText: 'Last name',
            ),
          ),
          _thinDivider(),
          _infoRow(
            label: 'Email',
            value: user.email,
            onTap: () => _editField(
              title: 'Email',
              initialValue: user.email,
              onSave: (v) => setState(() => user.email = v),
              keyboardType: TextInputType.emailAddress,
              hintText: 'you@example.com',
            ),
          ),
          _thinDivider(),
          _infoRow(
            label: 'Phone',
            value: user.phone,
            onTap: () => _editField(
              title: 'Phone',
              initialValue: user.phone,
              onSave: (v) => setState(() => user.phone = v),
              keyboardType: TextInputType.phone,
              hintText: '+91 98765 43210',
            ),
          ),
          _thinDivider(),
          _infoRow(
            label: 'Aadhaar / PAN',
            value: getMaskedId(user.idNumber),
            // allow editing the raw ID (careful: you may want stricter verification)
            onTap: () => _editField(
              title: 'Aadhaar / PAN',
              initialValue: user.idNumber,
              onSave: (v) => setState(() => user.idNumber = v),
              keyboardType: TextInputType.visiblePassword,
              hintText: 'Full Aadhaar or PAN',
              maxLength: 20,
            ),
          ),
          _thinDivider(),
          // Account status row - not editable here (you can change to editable if you want)
          Material(
            color: Colors.white,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Green dot when Verified, amber when Pending etc.
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _statusColor(user.accountStatus),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              user.accountStatus,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _thinDivider(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // determine color for status dot
  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('verify') || s.contains('active')) return Colors.green;
    if (s.contains('pending')) return Colors.orange;
    if (s.contains('blocked') || s.contains('suspended')) return Colors.red;
    return Colors.grey;
  }
}
