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
  final _formKey = GlobalKey<FormState>();
  final _refPromptCtrl = TextEditingController();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _tenantNameCtrl;
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

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _tenantNameCtrl = TextEditingController();
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
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        elevation: 0,
        foregroundColor: Colors.black,
        title: const Text(
          'Lease agreement',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (showPreview)
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _agreementText = null);
                    },
              child: const Text('Edit form'),
            ),
        ],
      ),
      body: _busy && !showPreview && _error == null
          ? const Center(child: CircularProgressIndicator())
          : showPreview
              ? _buildPreview()
              : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (_error != null) ...[
            MaterialBanner(
              content: Text(_error!),
              backgroundColor: Colors.orange.shade100,
              actions: [
                TextButton(onPressed: () => setState(() => _error = null), child: const Text('Dismiss')),
              ],
            ),
            const SizedBox(height: 12),
          ],
          const Text(
            'Enter lease details. Optional: add a reference prompt to customize clauses (or leave blank for the default template).',
            style: TextStyle(color: Colors.black54, height: 1.35),
          ),
          const SizedBox(height: 20),
          const _Sec('Property'),
          _tf(_nameCtrl, 'Property name', required: true),
          _tf(_addrCtrl, 'Address line'),
          _tf(_cityCtrl, 'City'),
          _tf(_stateCtrl, 'State'),
          _tf(_pinCtrl, 'Postal code'),
          const SizedBox(height: 16),
          const _Sec('Tenant'),
          _tf(_tenantNameCtrl, 'Tenant name'),
          _tf(_tenantPhoneCtrl, 'Tenant phone / WhatsApp'),
          const SizedBox(height: 16),
          const _Sec('Lease'),
          _tf(_startCtrl, 'Lease start (YYYY-MM-DD)', required: true),
          _tf(_endCtrl, 'Lease end (YYYY-MM-DD)', required: true),
          _tf(_rentCtrl, 'Monthly rent (₹)', num: true, required: true),
          _tf(_depositCtrl, 'Security deposit (₹)', num: true),
          _tf(_lockInCtrl, 'Lock-in (months)', num: true),
          _tf(_dueDayCtrl, 'Rent due day (1–31)', num: true, required: true),
          const SizedBox(height: 16),
          const _Sec('Reference prompt (optional)'),
          TextFormField(
            controller: _refPromptCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'e.g. Include pet policy, no subletting, 2 months notice…',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _generate,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1AAE9F),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Generate agreement'),
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
            backgroundColor: Colors.orange.shade100,
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
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black12),
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
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1AAE9F),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save lease'),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: num ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: required
            ? (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                return null;
              }
            : null,
      ),
    );
  }
}

class _Sec extends StatelessWidget {
  final String t;
  const _Sec(this.t);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
    );
  }
}
