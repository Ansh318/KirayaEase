import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class OnboardingForm extends StatefulWidget {
  const OnboardingForm({super.key});

  @override
  _OnboardingFormState createState() => _OnboardingFormState();
}

class _OnboardingFormState extends State<OnboardingForm> {
  final _formKey = GlobalKey<FormState>();
  String? _role;
  String? _sessionToken;

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _aadharController = TextEditingController();
  final _panController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSessionToken();
  }

  Future<void> _loadSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _sessionToken = prefs.getString("session_token");
    });
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      _dobController.text =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_sessionToken == null) {
      final prefs = await SharedPreferences.getInstance();
      _sessionToken = prefs.getString("session_token");
    }

    if (_sessionToken == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Session expired. Please log in again.")),
      );
      return;
    }

    final payload = {
      "session_token": _sessionToken,
      "first_name": _firstNameController.text.trim(),
      "last_name": _lastNameController.text.trim(),
      "date_of_birth": _dobController.text.trim(),
      "aadhar_card": _aadharController.text.trim(),
      "pan_number": _panController.text.trim(),
      "user_role": _role?.toLowerCase(),
    };
    print("Onboarding payload: ${jsonEncode(payload)}");

    try {
      final url = Uri.parse(
          'https://kirayaease-2a527d924296.herokuapp.com/user-onboarding');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        switch (_role?.toLowerCase()) {
          case 'tenant':
            Navigator.pushReplacementNamed((context), '/tenant');
            break;
          case 'landlord':
            Navigator.pushReplacementNamed(context, '/landlord');
            break;
          case 'property manager':
            Navigator.pushReplacementNamed(context, '/property-manager');
            break;
          default:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Unknown role. Cannot navigate.")),
            );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Error: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("💥 Exception: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: Color(0xFF00C6A6),
                child: Icon(Icons.person, size: 32, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome Aboard!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please provide your details to complete your onboarding',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.work),
                ),
                items: const [
                  DropdownMenuItem(value: 'Landlord', child: Text('Landlord')),
                  DropdownMenuItem(value: 'Tenant', child: Text('Tenant')),
                  DropdownMenuItem(
                      value: 'Property Manager',
                      child: Text('Property Manager')),
                ],
                onChanged: (val) => setState(() => _role = val),
                validator: (v) => v == null ? 'Please select a role' : null,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                        hintText: 'Enter first name',
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name',
                        hintText: 'Enter last name',
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dobController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Date of Birth',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                onTap: _pickDate,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _aadharController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Aadhar Card Number',
                  hintText: 'Enter 12‑digit Aadhar number',
                  prefixIcon: Icon(Icons.credit_card),
                ),
                maxLength: 12,
                validator: (v) =>
                    (v == null || v.length < 12) ? '12 digits required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _panController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'PAN Number',
                  hintText: 'ENTER PAN (E.g., ABCDE1234F)',
                  prefixIcon: Icon(Icons.description),
                ),
                validator: (v) =>
                    (v == null || v.length != 10) ? '10 chars required' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C6A6),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Complete Onboarding'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
