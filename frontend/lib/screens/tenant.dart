import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/ai_assistant.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart'; // ← Raz
import '../widgets/ai_assistant.dart';

class TenantDashboard extends StatefulWidget {
  const TenantDashboard({super.key});

  @override
  State<TenantDashboard> createState() => _TenantDashboardState();
}

class _TenantDashboardState extends State<TenantDashboard> {
  Map<String, dynamic>? userProfile;
  bool isLoading = true;
  String? error;
  Offset _assistantOffset = const Offset(20, 600);

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('session_token');

      final response = await http.get(
        Uri.parse('http://127.0.0.1:8000/user-profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          userProfile = jsonDecode(response.body);
          isLoading = false;
        });
      } else {
        setState(() {
          error = 'Failed to fetch profile';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        isLoading = false;
      });
    }
  }

  String getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning, ${userProfile?['first_name'] ?? ''}!";
    if (hour < 17)
      return "Good afternoon, ${userProfile?['first_name'] ?? ''}!";
    return "Good evening, ${userProfile?['first_name'] ?? ''}!";
  }

  void _showProfilePopup() {
    if (userProfile == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.4)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person, color: Colors.black87),
                        SizedBox(width: 8),
                        Text('Your Profile',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildProfileRow(
                      "Name",
                      "${userProfile!['first_name']} ${userProfile!['last_name']}",
                    ),
                    _buildProfileRow("Role", userProfile!['role']),
                    _buildProfileRow(
                        "Aadhaar", userProfile!["aadhar_card"] ?? "—"),
                    _buildProfileRow("PAN", userProfile!["pan_card"] ?? "—"),
                    _buildProfileRow("DOB", userProfile!["dob"]),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("Close",
                            style: TextStyle(color: Colors.black87)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildProfileRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text("$label: ${value ?? '—'}",
          style: const TextStyle(color: Colors.black87)),
    );
  }

  void _openAddPaymentSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddPaymentModal(),
    );
  }

  Widget buildMetricCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: Colors.black87),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCBF8F3),
      floatingActionButton: const AIAssistantChatWidget(),
      appBar: null,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text(error!))
              : Stack(
                  children: [
                    Positioned.fill(
                      child: ListView(
                        padding: const EdgeInsets.only(top: 80, bottom: 100),
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              getGreetingMessage(),
                              style: const TextStyle(
                                  fontSize: 26,
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              buildMetricCard("Active Lease", "1",
                                  Icons.assignment_turned_in_outlined),
                              buildMetricCard("Next Payment", "₹12,500",
                                  Icons.payments_outlined),
                              buildMetricCard("Split Status", "Enabled",
                                  Icons.swap_calls_outlined),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 40,
                      left: 20,
                      child: Image.asset(
                        'assets/logo.png',
                        height: 48,
                        width: 48,
                      ),
                    ),
                    Positioned(
                      left: _assistantOffset.dx,
                      top: _assistantOffset.dy,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            final Size screenSize = MediaQuery.of(context).size;
                            const double buttonSize = 60;
                            double newX =
                                _assistantOffset.dx + details.delta.dx;
                            double newY =
                                _assistantOffset.dy + details.delta.dy;
                            newX =
                                newX.clamp(0.0, screenSize.width - buttonSize);
                            newY = newY.clamp(
                                0.0,
                                screenSize.height -
                                    buttonSize -
                                    kToolbarHeight);
                            _assistantOffset = Offset(newX, newY);
                          });
                        },
                        child: const AIAssistantChatWidget(),
                      ),
                    ),
                  ],
                ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: const Color(0xFF00C6A6),
        type: BottomNavigationBarType.fixed,
        onTap: (index) async {
          switch (index) {
            case 0:
              break;
            case 1:
              _openAddPaymentSheet();
            case 2:
              if (!isLoading && userProfile != null) {
                _showProfilePopup();
              }
              break;
            case 3:
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('session_token');
              if (!mounted) return;
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/', (route) => false);
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_work_outlined), label: 'Properties'),
          BottomNavigationBarItem(
              icon: Icon(Icons.payments), label: 'Payments'),
          BottomNavigationBarItem(
              icon: Icon(Icons.account_circle), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Sign Out'),
        ],
      ),
    );
  }
}

class AddPaymentModal extends StatefulWidget {
  const AddPaymentModal({Key? key}) : super(key: key);

  @override
  State<AddPaymentModal> createState() => _AddPaymentModalState();
}

class _AddPaymentModalState extends State<AddPaymentModal> {
  final _upiController = TextEditingController();
  final _amountController = TextEditingController();
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handleError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternal);
    _amountController.addListener(() => setState(() {})); // updates button text
  }

  @override
  void dispose() {
    _upiController.dispose();
    _amountController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  void _handleSuccess(PaymentSuccessResponse response) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment successful!')),
    );
  }

  void _handleError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}')),
    );
  }

  void _handleExternal(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet: ${response.walletName}')),
    );
  }

  Future<void> _submitPayment() async {
    if (_amountController.text.isEmpty) return;

    try {
      final amount = int.parse(_amountController.text) * 100;

      final response = await http.post(
        Uri.parse(
            'https://kirayaease-2a527d924296.herokuapp.com//create-payment-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'receipt_id': 'rcptid_${DateTime.now().millisecondsSinceEpoch}',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final options = {
          'key': 'rzp_test_v4oAPsjPGsrOQR', // Replace with actual key
          'amount': amount,
          'currency': 'INR',
          'order_id': data['id'],
          'method': {
            'upi': true,
            'netbanking': true,
            'paylater': false,
            'card': true,
          },
          'theme': {'color': '#3399cc'},
        };

        _razorpay.open(options);
      } else {
        throw Exception('Failed to create payment order');
      }
    } catch (e) {
      debugPrint("Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      maxChildSize: 0.6,
      minChildSize: 0.3,
      builder: (_, ctrl) => Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Text(
              "Make a payment",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              "Powered by Razorpay",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: "Enter amount",
                prefixText: "₹ ",
                prefixStyle: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Image.asset(
                  'assets/razorpay.png', // 🔁 Replace with your SVG/icon asset
                  height: 40,
                  fit: BoxFit.contain,
                ),
                onPressed: _submitPayment,
                label: Text(
                  '',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF00C4FF), // Razorpay brand blue
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              "UPI, cards, and wallets via Razorpay Checkout.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
