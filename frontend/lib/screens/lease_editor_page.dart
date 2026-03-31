import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';

/// Manual create / edit lease (property + lease fields). Save → POST or PATCH `/leases`.
class LeaseEditorPage extends StatefulWidget {
  /// Null = create new lease.
  final String? leaseId;

  /// API row from `GET /leases` (same shape as list item) for prefill.
  final Map<String, dynamic>? initialRow;

  const LeaseEditorPage({super.key, this.leaseId, this.initialRow});

  @override
  State<LeaseEditorPage> createState() => _LeaseEditorPageState();
}

class _LeaseEditorPageState extends State<LeaseEditorPage> {
  final _formKey = GlobalKey<FormState>();
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

  bool _saving = false;

  bool get _isEdit => widget.leaseId != null && widget.leaseId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final m = widget.initialRow;
    _nameCtrl = TextEditingController(text: m?['property_name']?.toString() ?? '');
    _tenantNameCtrl = TextEditingController(text: m?['property_tenant_name']?.toString() ?? '');
    _tenantEmailCtrl = TextEditingController(text: m?['tenant_email']?.toString() ?? '');
    _tenantPhoneCtrl = TextEditingController(text: m?['tenant_phone']?.toString() ?? '');
    _addrCtrl = TextEditingController(text: m?['address_line1']?.toString() ?? '');
    _cityCtrl = TextEditingController(text: m?['city']?.toString() ?? '');
    _stateCtrl = TextEditingController(text: m?['state']?.toString() ?? '');
    _pinCtrl = TextEditingController(text: m?['postal_code']?.toString() ?? '');
    _startCtrl = TextEditingController(text: _isoDate(m?['lease_start']));
    _endCtrl = TextEditingController(text: _isoDate(m?['lease_end']));
    final rent = m?['monthly_rent'];
    _rentCtrl = TextEditingController(text: rent != null ? rent.toString() : '');
    final dep = m?['security_deposit'];
    _depositCtrl = TextEditingController(text: dep != null ? dep.toString() : '');
    final li = m?['lock_in_period'];
    _lockInCtrl = TextEditingController(text: li != null ? li.toString() : '');
    final dd = m?['due_day'];
    _dueDayCtrl = TextEditingController(text: dd != null ? dd.toString() : '1');
  }

  static String _isoDate(dynamic v) {
    if (v == null) return '';
    final s = v.toString();
    if (s.length >= 10) return s.substring(0, 10);
    return s;
  }

  @override
  void dispose() {
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id')?.trim();
    if (sessionId == null || sessionId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in again.')),
        );
      }
      return;
    }

    final rent = int.tryParse(_rentCtrl.text.trim());
    if (rent == null || rent < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid monthly rent (₹).')),
      );
      return;
    }
    final dueDay = int.tryParse(_dueDayCtrl.text.trim()) ?? 1;
    if (dueDay < 1 || dueDay > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Due day must be 1–31.')),
      );
      return;
    }

    final depStr = _depositCtrl.text.trim();
    final liStr = _lockInCtrl.text.trim();
    final body = <String, dynamic>{
      'property_name': _nameCtrl.text.trim(),
      'tenant_name': _nullIfEmpty(_tenantNameCtrl.text),
      'tenant_email': _nullIfEmpty(_tenantEmailCtrl.text),
      'tenant_phone': _nullIfEmpty(_tenantPhoneCtrl.text),
      'address_line1': _nullIfEmpty(_addrCtrl.text),
      'city': _nullIfEmpty(_cityCtrl.text),
      'state': _nullIfEmpty(_stateCtrl.text),
      'postal_code': _nullIfEmpty(_pinCtrl.text),
      'lease_start': _startCtrl.text.trim(),
      'lease_end': _endCtrl.text.trim(),
      'monthly_rent': rent,
      'due_day': dueDay,
    };
    body['security_deposit'] = depStr.isEmpty ? null : int.tryParse(depStr);
    body['lock_in_period'] = liStr.isEmpty ? null : int.tryParse(liStr);

    setState(() => _saving = true);
    try {
      final uri = _isEdit
          ? Uri.parse('${ApiConfig.baseUrl}/leases/${widget.leaseId}')
          : Uri.parse('${ApiConfig.baseUrl}/leases');
      final resp = await (_isEdit
          ? http.patch(
              uri,
              headers: {
                'Authorization': 'Bearer $sessionId',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            )
          : http.post(
              uri,
              headers: {
                'Authorization': 'Bearer $sessionId',
                'Content-Type': 'application/json',
              },
              body: jsonEncode(body),
            ));
      if (!mounted) return;
      if (resp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Lease saved.' : 'Lease created.')),
        );
        Navigator.of(context).pop(true);
      } else {
        var msg = 'Could not save (${resp.statusCode}).';
        try {
          final j = jsonDecode(utf8.decode(resp.bodyBytes));
          if (j is Map && j['detail'] != null) {
            final d = j['detail'];
            msg = d is List ? d.map((e) => e.toString()).join(', ') : d.toString();
          }
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Network error. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _nullIfEmpty(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text(
          _isEdit ? 'Edit lease' : 'New lease',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const _SectionTitle('Property'),
            _field(_nameCtrl, 'Property name', required: true),
            _field(_addrCtrl, 'Address line'),
            _field(_cityCtrl, 'City'),
            _field(_stateCtrl, 'State'),
            _field(_pinCtrl, 'Postal code', keyboard: TextInputType.number),
            const SizedBox(height: 16),
            const _SectionTitle('Tenant'),
            _field(_tenantNameCtrl, 'Tenant name'),
            _field(
              _tenantEmailCtrl,
              'Tenant email',
              hint: 'For DocuSeal signing',
              email: true,
            ),
            _field(_tenantPhoneCtrl, 'Tenant WhatsApp', hint: 'e.g. 9876543210 — rent reminders'),
            const SizedBox(height: 16),
            const _SectionTitle('Lease'),
            _field(_startCtrl, 'Lease start', hint: 'YYYY-MM-DD', required: true),
            _field(_endCtrl, 'Lease end', hint: 'YYYY-MM-DD', required: true),
            _field(_rentCtrl, 'Monthly rent (₹)', keyboard: TextInputType.number, required: true),
            _field(_depositCtrl, 'Security deposit (₹)', keyboard: TextInputType.number),
            _field(_lockInCtrl, 'Lock-in (months)', keyboard: TextInputType.number),
            _field(_dueDayCtrl, 'Rent due day (1–31)', keyboard: TextInputType.number, required: true),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1AAE9F),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(_isEdit ? 'Save changes' : 'Create lease'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    bool required = false,
    bool email = false,
    TextInputType? keyboard,
  }) {
    final effectiveKeyboard = keyboard ?? (email ? TextInputType.emailAddress : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: effectiveKeyboard,
        autocorrect: !email,
        inputFormatters: keyboard == TextInputType.number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Color(0xFF435365),
        ),
      ),
    );
  }
}
