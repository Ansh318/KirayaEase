// lib/onboarding_form.dart
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../services/digio_kyc_service.dart'; // startKycWorkflow(referenceId, customerIdentifier, {emailOrPhone, ...})

class OnboardingForm extends StatefulWidget {
  const OnboardingForm({super.key});
  @override
  State<OnboardingForm> createState() => _OnboardingFormState();
}

class _OnboardingFormState extends State<OnboardingForm> {
  static const String _baseUrl =
      'https://kirayaease-2a527d924296.herokuapp.com';

  final _formKey = GlobalKey<FormState>();

  // Inputs
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Focus
  final _phoneFocus = FocusNode();

  // Session / state
  String? _sessionToken;
  bool _verifying = false;
  bool _submitting = false;
  bool _verified = false;

  // Utils
  String _digits(String s) => s.replaceAll(RegExp(r'\D'), '');
  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _phoneValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final d = _digits(v);
    if (d.length != 10) return 'Enter a valid 10-digit mobile number';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(d))
      return 'Enter a valid Indian mobile number';
    return null;
  }

  Future<Map<String, dynamic>> _postJson(
      Uri url, Map<String, dynamic> body) async {
    final res = await http
        .post(url,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("${res.statusCode}: ${res.body}");
    }
    return res.body.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(res.body) as Map<String, dynamic>);
  }

  @override
  void initState() {
    super.initState();
    _loadSessionToken();
  }

  Future<void> _loadSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _sessionToken = prefs.getString("session_token"));
  }

  /// 1) Validate inputs
  /// 2) POST /digio-kyc  -> { reference_id, customer_identifier }
  /// 3) Launch Digio SDK via startKycWorkflow(...)
  Future<void> _startKyc() async {
    if (_verifying) return;

    // minimal validation (first + last + phone)
    if ((_required(_firstNameController.text) != null) ||
        (_required(_lastNameController.text) != null) ||
        (_phoneValidator(_phoneController.text) != null)) {
      _formKey.currentState?.validate();
      return;
    }

    _sessionToken ??=
        (await SharedPreferences.getInstance()).getString("session_token");
    if (_sessionToken == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Please log in again.")),
      );
      return;
    }

    setState(() => _verifying = true);
    try {
      // 1) backend: create Digio session
      final startUrl = Uri.parse('$_baseUrl/digio-kyc');
      final startData = await _postJson(startUrl, {
        "session_token": _sessionToken,
        "phone_number": "+91${_digits(_phoneController.text)}",
        "first_name": _firstNameController.text.trim(),
        "last_name": _lastNameController.text.trim(), // ← FIXED
      });

      // 2) extract required fields
      final referenceId = startData['reference_id']?.toString();
      final customerIdentifier = startData['customer_identifier']?.toString();
      if (referenceId == null || customerIdentifier == null) {
        throw Exception("Backend missing reference_id / customer_identifier");
      }

      // 3) launch Digio SDK
      await startKycWorkflow(
        customerId: referenceId,
        nameOrOtherId: customerIdentifier,
        emailOrPhone:
            "+91${_digits(_phoneController.text)}", // pass phone to SDK helper
      );

      if (!mounted) return;
      setState(() => _verified = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("KYC flow started ✅")),
      );
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("KYC failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_verified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete verification first.")),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = true);
    try {
      Navigator.pushReplacementNamed(context, '/tenant');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("💥 $e")));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose(); // ← dispose last name controller
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inputDecoration = const InputDecoration(
      filled: true,
      fillColor: Color(0xFFF7FBFB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: Colors.black54),
      hintStyle: TextStyle(color: Colors.black38),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xCCFFFFFF),
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 24,
                  offset: Offset(0, 10))
            ],
            border: Border.all(color: const Color(0x1A00C6A6)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 2),
                const Center(
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFF9BE7DB),
                    child: Icon(Icons.person, size: 28, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Complete Your Onboarding',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'We’ll keep your info secure and private.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 20),

                // First Name
                TextFormField(
                  controller: _firstNameController,
                  decoration: inputDecoration.copyWith(
                    labelText: 'First Name',
                    hintText: 'Enter first name',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: _required,
                ),
                const SizedBox(height: 12),

                // Last Name
                TextFormField(
                  controller: _lastNameController,
                  decoration: inputDecoration.copyWith(
                    labelText: 'Last Name',
                    hintText: 'Enter last name',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: _required,
                ),
                const SizedBox(height: 12),

                // Phone
                TextFormField(
                  controller: _phoneController,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: inputDecoration.copyWith(
                    labelText: 'Mobile Number',
                    hintText: '10-digit number',
                    prefixText: '+91 ',
                  ),
                  validator: _phoneValidator,
                  onFieldSubmitted: (_) => _startKyc(),
                ),
                const SizedBox(height: 16),

                // VERIFY BUTTON
                InkWell(
                  onTap: _verifying ? null : _startKyc,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2FAF9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _verified
                            ? const Color(0xFF21A07A)
                            : const Color(0x2200C6A6),
                        width: 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(
                          _verified
                              ? Icons.verified_rounded
                              : Icons.phone_android_rounded,
                          color: _verified
                              ? const Color(0xFF21A07A)
                              : Colors.black54,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _verified
                                ? 'Identity Verified'
                                : 'Verify via Mobile (Digio)',
                            style: TextStyle(
                              fontWeight:
                                  _verified ? FontWeight.w600 : FontWeight.w500,
                              color: _verified
                                  ? const Color(0xFF167D60)
                                  : Colors.black87,
                            ),
                          ),
                        ),
                        if (_verifying)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      backgroundColor: Colors.white,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      shadowColor: const Color(0x11000000),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Complete Onboarding'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
