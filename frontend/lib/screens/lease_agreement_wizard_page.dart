import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// LLM lease agreement: collect facts + optional reference prompt → generate → preview → save.
/// Opened when chat returns `action: open_lease_agreement_widget` or `open_lease_agreement_preview`.
class LeaseAgreementWizardPage extends StatefulWidget {
  /// Jump straight to preview (e.g. after agent ran generate).
  final bool startOnPreview;

  const LeaseAgreementWizardPage({super.key, this.startOnPreview = false});

  @override
  State<LeaseAgreementWizardPage> createState() => _LeaseAgreementWizardPageState();
}

class _LeaseAgreementWizardPageState extends State<LeaseAgreementWizardPage> {
  static const _ink = Color(0xFF1A1A1A);
  static const _muted = Color(0xFF6B6B6B);
  static const _teal = Color(0xFF1AAE9F);
  static const _tealSoft = Color(0xFFE8F7F5);
  static const _surface = Color(0xFFFFFFFF);
  static const _pageBg = Color(0xFFF4F6F8);

  final _formKey = GlobalKey<FormState>();
  final _refPromptCtrl = TextEditingController();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _tenantNameCtrl;
  late final TextEditingController _tenantEmailCtrl;
  late final TextEditingController _tenantPhoneCtrl;
  late final TextEditingController _addrCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _pinCtrl;
  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;
  late final TextEditingController _rentCtrl;
  late final TextEditingController _depositCtrl;
  late final TextEditingController _lockInCtrl;
  late final TextEditingController _dueDayCtrl;

  bool _busy = false;
  String? _agreementText;
  String? _error;

  OutlineInputBorder _fieldBorder(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );

  InputDecoration _decoration(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _fieldBorder(const Color(0xFFE2E8E4)),
      enabledBorder: _fieldBorder(const Color(0xFFE2E8E4)),
      focusedBorder: _fieldBorder(_teal, 1.5),
      errorBorder: _fieldBorder(Colors.red.shade300),
      focusedErrorBorder: _fieldBorder(Colors.red.shade400, 1.5),
      labelStyle: const TextStyle(color: _muted, fontWeight: FontWeight.w500, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: _teal, fontWeight: FontWeight.w600, fontSize: 13),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
    );
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _tenantNameCtrl = TextEditingController();
    _tenantEmailCtrl = TextEditingController();
    _tenantPhoneCtrl = TextEditingController();
    _addrCtrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _stateCtrl = TextEditingController();
    _pinCtrl = TextEditingController();
    _startCtrl = TextEditingController();
    _endCtrl = TextEditingController();
    _rentCtrl = TextEditingController();
    _depositCtrl = TextEditingController();
    _lockInCtrl = TextEditingController();
    _dueDayCtrl = TextEditingController(text: '1');
    if (widget.startOnPreview) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchPreview());
    }
  }

  @override
  void dispose() {
    _refPromptCtrl.dispose();
    _nameCtrl.dispose();
    _tenantNameCtrl.dispose();
    _tenantEmailCtrl.dispose();
    _tenantPhoneCtrl.dispose();
    _addrCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pinCtrl.dispose();
    _startCtrl.dispose();
    _endCtrl.dispose();
    _rentCtrl.dispose();
    _depositCtrl.dispose();
    _lockInCtrl.dispose();
    _dueDayCtrl.dispose();
    super.dispose();
  }

  Future<String?> _sessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('session_id')?.trim();
  }

  Map<String, dynamic> _leasePayload() {
    final rent = int.tryParse(_rentCtrl.text.trim()) ?? 0;
    final dueDay = int.tryParse(_dueDayCtrl.text.trim()) ?? 1;
    final depStr = _depositCtrl.text.trim();
    final liStr = _lockInCtrl.text.trim();
    return {
      'property_name': _nameCtrl.text.trim(),
      'tenant_name': _tenantNameCtrl.text.trim().isEmpty ? null : _tenantNameCtrl.text.trim(),
      'tenant_email': _tenantEmailCtrl.text.trim().isEmpty ? null : _tenantEmailCtrl.text.trim(),
      'tenant_phone': _tenantPhoneCtrl.text.trim().isEmpty ? null : _tenantPhoneCtrl.text.trim(),
      'address_line1': _addrCtrl.text.trim().isEmpty ? null : _addrCtrl.text.trim(),
      'city': _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim().isEmpty ? null : _stateCtrl.text.trim(),
      'postal_code': _pinCtrl.text.trim().isEmpty ? null : _pinCtrl.text.trim(),
      'lease_start': _startCtrl.text.trim(),
      'lease_end': _endCtrl.text.trim(),
      'monthly_rent': rent,
      'due_day': dueDay,
      'security_deposit': depStr.isEmpty ? null : int.tryParse(depStr),
      'lock_in_period': liStr.isEmpty ? null : int.tryParse(liStr),
    };
  }

  Future<void> _fetchPreview() async {
    final token = await _sessionToken();
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Please sign in again.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final resp = await http.get(
        Uri.parse(ApiConfig.leaseAgreementPreviewEndpoint),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        final text = data['agreement_text']?.toString();
        setState(() {
          _agreementText = text;
          _busy = false;
        });
        if (text == null || text.isEmpty) {
          setState(() => _error = 'No agreement text yet. Fill the form and tap Generate.');
        }
      } else {
        setState(() {
          _busy = false;
          _error = 'No preview available yet. Use the form and generate first.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not load preview.';
        });
      }
    }
  }

  Future<void> _generate() async {
    if (!_formKey.currentState!.validate()) return;
    final token = await _sessionToken();
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again.')),
      );
      return;
    }
    final rent = int.tryParse(_rentCtrl.text.trim());
    if (rent == null || rent < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid monthly rent.')),
      );
      return;
    }
    final due = int.tryParse(_dueDayCtrl.text.trim()) ?? 1;
    if (due < 1 || due > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Due day must be 1–31.')),
      );
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ref = _refPromptCtrl.text.trim();
      final body = <String, dynamic>{
        'lease': _leasePayload(),
        if (ref.isNotEmpty) 'reference_prompt': ref,
      };
      final resp = await http.post(
        Uri.parse(ApiConfig.leaseAgreementGenerateEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
        setState(() {
          _agreementText = data['agreement_text']?.toString();
          _busy = false;
        });
        if (_agreementText == null || _agreementText!.isEmpty) {
          setState(() => _error = 'Empty response from server.');
        }
      } else {
        var msg = 'Generate failed (${resp.statusCode}).';
        try {
          final j = jsonDecode(utf8.decode(resp.bodyBytes));
          if (j is Map && j['detail'] != null) {
            msg = j['detail'].toString();
          }
        } catch (_) {}
        setState(() {
          _busy = false;
          _error = msg;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Network error. Try again.';
        });
      }
    }
  }

  Future<void> _save() async {
    final token = await _sessionToken();
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final resp = await http.post(
        Uri.parse(ApiConfig.leaseAgreementSaveEndpoint),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lease saved with full agreement.')),
        );
        Navigator.of(context).pop(true);
      } else {
        var msg = 'Save failed (${resp.statusCode}).';
        try {
          final j = jsonDecode(utf8.decode(resp.bodyBytes));
          if (j is Map && j['detail'] != null) {
            msg = j['detail'].toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        setState(() => _busy = false);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error.')),
        );
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final showPreview = _agreementText != null && _agreementText!.isNotEmpty;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: _pageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _ink,
        title: const Text(
          'Lease agreement',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.2),
        ),
        actions: [
          if (showPreview)
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _agreementText = null);
                    },
              child: const Text('Edit form', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: _busy && !showPreview && _error == null
          ? const Center(child: CircularProgressIndicator(color: _teal))
          : showPreview
              ? _buildPreview()
              : _buildForm(),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _tealSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _teal.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, size: 22, color: _teal.shade700),
              const SizedBox(width: 8),
              Text(
                'How it works',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: _teal.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _introBullet('Enter lease details'),
          _introBullet('We’ll generate a ready-to-sign lease for you.'),
          _introBullet('Add any special terms (optional)'),
        ],
      ),
    );
  }

  Widget _introBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _teal,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _teal.withValues(alpha: 0.35),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: _ink,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required IconData icon, required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE8ECEA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _tealSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: _teal.shade700),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.2,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 36),
        children: [
          if (_error != null) ...[
            MaterialBanner(
              content: Text(_error!),
              backgroundColor: Colors.orange.shade50,
              actions: [
                TextButton(onPressed: () => setState(() => _error = null), child: const Text('Dismiss')),
              ],
            ),
            const SizedBox(height: 12),
          ],
          _buildIntroCard(),
          const SizedBox(height: 20),
          _sectionCard(
            icon: Icons.apartment_rounded,
            title: 'Property',
            children: [
              _tf(_nameCtrl, 'Property name', required: true),
              _tf(_addrCtrl, 'Address line'),
              _tf(_cityCtrl, 'City'),
              _tf(_stateCtrl, 'State'),
              _tf(_pinCtrl, 'Postal code'),
            ],
          ),
          _sectionCard(
            icon: Icons.person_outline_rounded,
            title: 'Tenant',
            children: [
              _tf(_tenantNameCtrl, 'Tenant name'),
              _tf(
                _tenantEmailCtrl,
                'Tenant email',
                hint: 'For DocuSeal signing',
                email: true,
              ),
              _tf(
                _tenantPhoneCtrl,
                'Tenant WhatsApp',
                hint: 'Optional — rent reminders',
              ),
            ],
          ),
          _sectionCard(
            icon: Icons.calendar_month_rounded,
            title: 'Lease',
            children: [
              _tf(_startCtrl, 'Lease start', hint: 'YYYY-MM-DD', required: true),
              _tf(_endCtrl, 'Lease end', hint: 'YYYY-MM-DD', required: true),
              _tf(_rentCtrl, 'Monthly rent', hint: '₹', num: true, required: true),
              _tf(_depositCtrl, 'Security deposit', hint: '₹', num: true),
              _tf(_lockInCtrl, 'Lock-in period', hint: 'Months', num: true),
              _tf(_dueDayCtrl, 'Rent due day', hint: '1–31', num: true, required: true),
            ],
          ),
          _sectionCard(
            icon: Icons.notes_rounded,
            title: 'Additional information',
            children: [
              TextFormField(
                controller: _refPromptCtrl,
                maxLines: 4,
                decoration: _decoration(
                  'Optional notes for the agreement',
                  hint: 'e.g. pet policy, no subletting, notice period…',
                ).copyWith(
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Material(
            elevation: 0,
            borderRadius: BorderRadius.circular(14),
            shadowColor: _teal.withValues(alpha: 0.45),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF1AAE9F), Color(0xFF158F7A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _teal.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _busy ? null : _generate,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Generate agreement',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null)
          MaterialBanner(
            content: Text(_error!),
            backgroundColor: Colors.orange.shade50,
            actions: [
              TextButton(onPressed: () => setState(() => _error = null), child: const Text('Dismiss')),
            ],
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Text(
            'Preview — review before saving. Not legal advice.',
            style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8ECEA)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                _agreementText ?? '',
                style: const TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => setState(() => _agreementText = null),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save lease', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tf(
    TextEditingController c,
    String label, {
    bool required = false,
    bool num = false,
    bool email = false,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: num
            ? TextInputType.number
            : email
                ? TextInputType.emailAddress
                : TextInputType.text,
        autocorrect: !email,
        decoration: _decoration(label, hint: hint),
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) return 'Required';
          if (email) {
            final t = v?.trim() ?? '';
            if (t.isNotEmpty && (t.length < 5 || !t.contains('@'))) {
              return 'Enter a valid email';
            }
          }
          return null;
        },
      ),
    );
  }
}

extension on Color {
  Color get shade700 => Color.lerp(this, Colors.black, 0.12)!;
  Color get shade800 => Color.lerp(this, Colors.black, 0.2)!;
}
