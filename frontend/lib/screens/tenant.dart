// // tenant_dashboard_v2.dart
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:razorpay_flutter/razorpay_flutter.dart';
// import 'package:shared_preferences/shared_preferences.dart';
// import '../widgets/ai_assistant.dart';

// class TenantDashboardV2 extends StatefulWidget {
//   const TenantDashboardV2({super.key});

//   @override
//   State<TenantDashboardV2> createState() => _TenantDashboardV2State();
// }

// class _TenantDashboardV2State extends State<TenantDashboardV2> {
//   final Color bgColor = const Color(0xFFCBF8F3);

//   String getGreetingMessage() {
//     final hour = DateTime.now().hour;
//     if (hour < 12) return "Good morning, Ansh!";
//     if (hour < 17) return "Good afternoon, Ansh!";
//     return "Good evening, Ansh!";
//   }

//   void _openAddPaymentSheet() {
//     showModalBottomSheet<void>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => const AddPaymentModal(),
//     );
//   }

//   Future<void> _signOut() async {
//     final prefs = await SharedPreferences.getInstance();
//     await prefs.remove('session_token');
//     if (!mounted) return;
//     Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: bgColor,
//       body: SafeArea(
//         child: ListView(
//           // Moved everything up a bit to create space for the promo card
//           padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
//           children: [
//             // Logo (slightly smaller + less spacing)
//             Row(
//               children: [
//                 Image.asset('assets/logo.png', height: 32, width: 32),
//               ],
//             ),
//             const SizedBox(height: 8),

//             // Greeting (moved up)
//             Text(
//               getGreetingMessage(),
//               style: const TextStyle(
//                 fontSize: 26,
//                 fontWeight: FontWeight.w600,
//                 color: Colors.black87,
//               ),
//             ),
//             const SizedBox(height: 12),

//             // ===== Promo Card (broader/taller, matches second picture) =====
//             const _PromoCardExact(),
//             const SizedBox(height: 20),

//             // === Rent Summary Card ===
//             Container(
//               decoration: BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.circular(16),
//                 boxShadow: const [
//                   BoxShadow(
//                     blurRadius: 20,
//                     offset: Offset(0, 10),
//                     color: Color(0x14000000),
//                   ),
//                 ],
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Padding(
//                     padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
//                     child: Row(
//                       children: [
//                         Expanded(
//                           child: Text(
//                             'Monthly Rent',
//                             style: TextStyle(
//                               fontSize: 15,
//                               fontWeight: FontWeight.w600,
//                               color: Colors.black87,
//                             ),
//                           ),
//                         ),
//                         Icon(Icons.chevron_right_rounded,
//                             color: Colors.black45),
//                       ],
//                     ),
//                   ),
//                   const Padding(
//                     padding: EdgeInsets.symmetric(horizontal: 16),
//                     child: Text(
//                       '₹12,500',
//                       style: TextStyle(
//                         fontSize: 36,
//                         fontWeight: FontWeight.w800,
//                         letterSpacing: -0.5,
//                         color: Colors.black,
//                       ),
//                     ),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
//                     child: Container(
//                       padding: const EdgeInsets.symmetric(
//                         horizontal: 12,
//                         vertical: 10,
//                       ),
//                       decoration: BoxDecoration(
//                         color: const Color(0xFFF7F7F9),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       child: const Row(
//                         children: [
//                           Icon(Icons.circle, size: 8, color: Colors.amber),
//                           SizedBox(width: 8),
//                           Expanded(
//                             child: Text(
//                               'Your property will receive ₹12,500 on Oct 1st',
//                               style: TextStyle(
//                                   fontSize: 13, color: Colors.black87),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                   const Divider(height: 1, color: Color(0xFFECECEC)),
//                   const Padding(
//                     padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
//                     child: Text(
//                       'Payments',
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w700,
//                         color: Colors.black87,
//                       ),
//                     ),
//                   ),
//                   const _PaymentRow(title: 'Wed, Oct 1st', amount: '₹9,000'),
//                   const _PaymentRow(title: 'Wed, Oct 17th', amount: '₹3,500'),
//                   const Padding(
//                     padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
//                     child: Text(
//                       'Payment methods',
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w700,
//                         color: Colors.black87,
//                       ),
//                     ),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
//                     child: Row(
//                       children: [
//                         Container(
//                           padding: const EdgeInsets.symmetric(
//                             horizontal: 10,
//                             vertical: 8,
//                           ),
//                           decoration: BoxDecoration(
//                             color: const Color(0xFFF7F7F9),
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           child: const Row(
//                             children: [
//                               Icon(Icons.account_balance_wallet_outlined,
//                                   size: 18, color: Colors.black87),
//                               SizedBox(width: 8),
//                               Text('UPI • ****1234',
//                                   style: TextStyle(color: Colors.black87)),
//                             ],
//                           ),
//                         ),
//                         const Spacer(),
//                         GestureDetector(
//                           onTap: _openAddPaymentSheet,
//                           child: const Text(
//                             'Add funds',
//                             style: TextStyle(
//                               decoration: TextDecoration.underline,
//                               color: Colors.black87,
//                               fontWeight: FontWeight.w600,
//                             ),
//                           ),
//                         )
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//       bottomNavigationBar: BottomNavigationBar(
//         backgroundColor: bgColor,
//         elevation: 0,
//         selectedItemColor: Colors.black,
//         unselectedItemColor: Colors.grey[600],
//         type: BottomNavigationBarType.fixed,
//         onTap: (index) async {
//           switch (index) {
//             case 0:
//               break;
//             case 1:
//               _openAddPaymentSheet();
//               break;
//             case 2:
//               Navigator.pushNamed(context, '/settings');
//               break;
//             case 3:
//               await _signOut();
//               break;
//           }
//         },
//         items: const [
//           BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
//           BottomNavigationBarItem(
//               icon: Icon(Icons.payments), label: 'Payments'),
//           BottomNavigationBarItem(
//               icon: Icon(Icons.settings), label: 'Settings'),
//           BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Sign Out'),
//         ],
//       ),
//     );
//   }
// }

// /// Beige promo card with wider/taller proportions, subtle arcs, and NFC waves.
// class _PromoCardExact extends StatelessWidget {
//   const _PromoCardExact();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       height: 136, // broader/taller
//       decoration: BoxDecoration(
//         color: const Color.fromARGB(255, 255, 255, 255), // warm beige
//         borderRadius: BorderRadius.circular(16),
//         boxShadow: const [
//           BoxShadow(
//             blurRadius: 16,
//             offset: Offset(0, 8),
//             color: Color(0x14000000),
//           ),
//         ],
//       ),
//       child: CustomPaint(
//         painter: _PromoArcsPainter(),
//         child: Padding(
//           // a bit more inner breathing space to look premium
//           padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               const _ContactlessWaves(),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: const [
//                     Flexible(
//                       child: Text(
//                         'Get up to ₹1,00,000 in Rent Credit',
//                         maxLines: 2,
//                         overflow: TextOverflow.ellipsis,
//                         style: TextStyle(
//                           fontSize: 19, // slightly larger
//                           height: 1.25,
//                           fontWeight: FontWeight.w800,
//                           letterSpacing: -0.2,
//                           color: Colors.black87,
//                         ),
//                       ),
//                     ),
//                     SizedBox(height: 8),
//                     Text(
//                       'Pay on your schedule.',
//                       style: TextStyle(
//                         fontSize: 15,
//                         height: 1.2,
//                         fontWeight: FontWeight.w500,
//                         color: Colors.black54,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// /// Paint the faint overlapping arcs like the reference (sweep further across).
// class _PromoArcsPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final arcStroke = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 1.1
//       ..color = const Color(0x22000000); // very subtle

//     final fillPaint = Paint()
//       ..style = PaintingStyle.fill
//       ..color = const Color(0x10000000); // translucent plate

//     final clip = RRect.fromRectAndRadius(
//       Offset.zero & size,
//       const Radius.circular(16),
//     );
//     canvas.clipRRect(clip);

//     // Large soft disc from left-bottom
//     final discCenter = Offset(size.width * 0.18, size.height * 1.05);
//     canvas.drawCircle(discCenter, size.width * 0.65, fillPaint);

//     // Two sweeping arcs from top-right to center-left
//     final arc1 = Rect.fromCircle(
//       center: Offset(size.width * 0.75, size.height * -0.10),
//       radius: size.width * 0.95,
//     );
//     final arc2 = Rect.fromCircle(
//       center: Offset(size.width * 0.78, size.height * 0.05),
//       radius: size.width * 1.15,
//     );

//     canvas.drawArc(arc1, 1.05, 1.25, false, arcStroke);
//     canvas.drawArc(arc2, 1.05, 1.25, false, arcStroke);
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }

// /// Small NFC/contactless icon built from three arcs.
// class _ContactlessWaves extends StatelessWidget {
//   const _ContactlessWaves({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return CustomPaint(
//       size: const Size(22, 22),
//       painter: _WavesPainter(),
//     );
//   }
// }

// class _WavesPainter extends CustomPainter {
//   @override
//   void paint(Canvas canvas, Size size) {
//     final p = Paint()
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 2
//       ..strokeCap = StrokeCap.round
//       ..color = Colors.black87;

//     for (int i = 0; i < 3; i++) {
//       final r = 4.0 + i * 3.2;
//       final rect =
//           Rect.fromCircle(center: Offset(r + 1.5, size.height / 2), radius: r);
//       canvas.drawArc(rect, -0.6, 1.2, false, p);
//     }

//     final dot = Paint()..color = Colors.black87;
//     canvas.drawCircle(Offset(2, size.height / 2), 1.7, dot);
//   }

//   @override
//   bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
// }

// class _PaymentRow extends StatelessWidget {
//   final String title;
//   final String amount;
//   const _PaymentRow({required this.title, required this.amount});

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       child: Container(
//         padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
//         decoration: BoxDecoration(
//           color: const Color(0xFFF7F7F9),
//           borderRadius: BorderRadius.circular(12),
//         ),
//         child: Row(
//           children: [
//             const Icon(Icons.event_rounded, color: Colors.black87),
//             const SizedBox(width: 10),
//             Expanded(
//               child: Text(
//                 title,
//                 style:
//                     const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
//               ),
//             ),
//             Text(amount,
//                 style:
//                     const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
//             const SizedBox(width: 6),
//             const Icon(Icons.chevron_right_rounded, color: Colors.black45),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ==========================
// // Add Payment Bottom Sheet (improved)
// // ==========================
// class AddPaymentModal extends StatefulWidget {
//   const AddPaymentModal({Key? key}) : super(key: key);

//   @override
//   State<AddPaymentModal> createState() => _AddPaymentModalState();
// }

// class _AddPaymentModalState extends State<AddPaymentModal> {
//   final _amountController = TextEditingController();
//   late Razorpay _razorpay;

//   @override
//   void initState() {
//     super.initState();
//     _razorpay = Razorpay()
//       ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess)
//       ..on(Razorpay.EVENT_PAYMENT_ERROR, _handleError)
//       ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternal);
//     _amountController.addListener(() => setState(() {}));
//   }

//   @override
//   void dispose() {
//     _amountController.dispose();
//     _razorpay.clear();
//     super.dispose();
//   }

//   void _handleSuccess(PaymentSuccessResponse response) {
//     if (mounted) Navigator.pop(context);
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('Payment successful!')),
//     );
//   }

//   void _handleError(PaymentFailureResponse response) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('Payment failed: ${response.message}')),
//     );
//   }

//   void _handleExternal(ExternalWalletResponse response) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(content: Text('External Wallet: ${response.walletName}')),
//     );
//   }

//   Future<void> _submitPayment() async {
//     FocusScope.of(context).unfocus(); // hide keyboard first
//     final raw = _amountController.text.trim();
//     if (raw.isEmpty) return;

//     try {
//       final amount = int.parse(raw) * 100; // INR → paise

//       final response = await http.post(
//         Uri.parse(
//             'https://kirayaease-2a527d924296.herokuapp.com/create-payment-order'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           'amount': amount,
//           'receipt_id': 'rcptid_${DateTime.now().millisecondsSinceEpoch}',
//         }),
//       );

//       if (response.statusCode != 200) {
//         throw Exception('Failed to create payment order');
//       }
//       final data = jsonDecode(response.body);

//       final options = {
//         'key': 'rzp_test_v4oAPsjPGsrOQR', // TODO: replace with live key in prod
//         'amount': amount,
//         'currency': 'INR',
//         'order_id': data['id'],
//         'method': {
//           'upi': true,
//           'netbanking': true,
//           'paylater': false,
//           'card': true
//         },
//         'theme': {'color': '#3399cc'},
//       };

//       _razorpay.open(options);
//     } catch (e) {
//       debugPrint('Error: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Payment failed')),
//       );
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final buttonText = _amountController.text.isEmpty
//         ? 'Pay securely'
//         : 'Pay ₹${_amountController.text}';

//     return DraggableScrollableSheet(
//       initialChildSize: 0.5,
//       maxChildSize: 0.95,
//       minChildSize: 0.32,
//       expand: false, // <-- allow it to shrink under keyboard
//       builder: (context, scrollController) {
//         final bottomInset = MediaQuery.of(context).viewInsets.bottom;
//         return AnimatedPadding(
//           duration: const Duration(milliseconds: 200),
//           curve: Curves.easeOut,
//           padding:
//               EdgeInsets.only(bottom: bottomInset), // <-- lift above keyboard
//           child: Material(
//             color: Colors.white,
//             borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
//             child: SafeArea(
//               top: false,
//               child: SingleChildScrollView(
//                 controller: scrollController,
//                 keyboardDismissBehavior:
//                     ScrollViewKeyboardDismissBehavior.onDrag,
//                 padding:
//                     const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     // Grab handle
//                     Center(
//                       child: Container(
//                         width: 42,
//                         height: 4,
//                         margin: const EdgeInsets.only(bottom: 16),
//                         decoration: BoxDecoration(
//                           color: const Color(0x22000000),
//                           borderRadius: BorderRadius.circular(2),
//                         ),
//                       ),
//                     ),

//                     Text(
//                       'Make a payment',
//                       style: Theme.of(context)
//                           .textTheme
//                           .titleLarge
//                           ?.copyWith(fontWeight: FontWeight.bold),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 8),
//                     Text('Powered by Razorpay',
//                         textAlign: TextAlign.center,
//                         style: Theme.of(context).textTheme.bodyMedium),
//                     const SizedBox(height: 24),

//                     TextFormField(
//                       controller: _amountController,
//                       keyboardType: TextInputType.number,
//                       textInputAction: TextInputAction.done,
//                       onFieldSubmitted: (_) => _submitPayment(),
//                       style: const TextStyle(
//                           fontSize: 20, fontWeight: FontWeight.bold),
//                       decoration: InputDecoration(
//                         hintText: 'Enter amount',
//                         prefixText: '₹ ',
//                         prefixStyle: const TextStyle(
//                           fontSize: 20,
//                           fontWeight: FontWeight.bold,
//                           color: Colors.black,
//                         ),
//                         filled: true,
//                         fillColor: const Color(0xFFF4F5F7),
//                         border: OutlineInputBorder(
//                           borderRadius: BorderRadius.circular(12),
//                           borderSide: BorderSide.none,
//                         ),
//                         contentPadding: const EdgeInsets.symmetric(
//                             vertical: 20, horizontal: 16),
//                       ),
//                     ),

//                     const SizedBox(height: 24),

//                     // Sticky-ish CTA (stays visible because of viewInsets padding)
//                     ElevatedButton.icon(
//                       icon: Image.asset('assets/razorpay.png',
//                           height: 40, fit: BoxFit.contain),
//                       onPressed: _submitPayment,
//                       label: Text(buttonText),
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: const Color(0xFF00C4FF),
//                         padding: const EdgeInsets.symmetric(vertical: 16),
//                       ),
//                     ),

//                     const SizedBox(height: 12),
//                     Text(
//                       'UPI, cards, and wallets via Razorpay Checkout.',
//                       textAlign: TextAlign.center,
//                       style: Theme.of(context)
//                           .textTheme
//                           .bodySmall
//                           ?.copyWith(color: Colors.black54),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
// }

// tenant_dashboard_v2.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/ai_assistant.dart';

class TenantDashboardV2 extends StatefulWidget {
  const TenantDashboardV2({super.key});

  @override
  State<TenantDashboardV2> createState() => _TenantDashboardV2State();
}

class _TenantDashboardV2State extends State<TenantDashboardV2> {
  final Color bgColor = const Color(0xFFCBF8F3);

  String getGreetingMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning, Ansh!";
    if (hour < 17) return "Good afternoon, Ansh!";
    return "Good evening, Ansh!";
  }

  void _openAddPaymentSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddPaymentModal(),
    );
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_token');
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            // Logo
            Row(
              children: [
                Image.asset('assets/logo.png', height: 32, width: 32),
              ],
            ),
            const SizedBox(height: 8),

            // Greeting
            Text(
              getGreetingMessage(),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            // ===== Promo Card (elevated & roomier) =====
            const _PromoCardExact(),
            const SizedBox(height: 20),

            // === Rent Summary Card ===
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  // ambient + key shadow
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Color(0x07000000),
                    blurRadius: 8,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Monthly Rent',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded,
                            color: Colors.black45),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      '₹12,500',
                      style: TextStyle(
                        fontSize: 34, // slightly reduced
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.amber),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your property will receive ₹12,500 on Oct 1st',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFECECEC)),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      'Payments',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const _PaymentRow(title: 'Wed, Oct 1st', amount: '₹9,000'),
                  const _PaymentRow(title: 'Wed, Oct 17th', amount: '₹3,500'),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'Payment methods',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.account_balance_wallet_outlined,
                                  size: 18, color: Colors.black87),
                              SizedBox(width: 8),
                              Text('UPI • ****1234',
                                  style: TextStyle(color: Colors.black87)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _openAddPaymentSheet,
                          child: const Text(
                            'Add funds',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: bgColor,
        elevation: 0,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
        onTap: (index) async {
          switch (index) {
            case 0:
              break;
            case 1:
              _openAddPaymentSheet();
              break;
            case 2:
              Navigator.pushNamed(context, '/settings');
              break;
            case 3:
              await _signOut();
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.payments), label: 'Payments'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
          BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Sign Out'),
        ],
      ),
    );
  }
}

/// Premium promo card with stronger vertical elevation and extra breathing room.
class _PromoCardExact extends StatelessWidget {
  const _PromoCardExact();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 156, // taller so it reads as a card
      decoration: BoxDecoration(
        // Subtle vertical gradient so it doesn’t feel flat
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFDFDFD),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x11000000)),
        boxShadow: const [
          // soft ambient
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            spreadRadius: 2,
            offset: Offset(0, 8),
          ),
          // slight “lift” shadow closer to the card
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // faint arcs & disc
            CustomPaint(
              painter: _PromoArcsPainter(),
              size: Size.infinite,
            ),
            // very light inner highlight at top for depth
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [
                        Colors.white.withOpacity(0.28),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // content
            Padding(
              // more top padding so subtitle can sit lower
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _ContactlessWaves(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        // Title slightly smaller, still bold
                        Text(
                          'Get up to ₹1,00,000 in Rent Credit',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 18, // reduced a bit
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 12), // extra space before subtitle
                        Text(
                          'Pay on your schedule.',
                          style: TextStyle(
                            fontSize: 14, // reduced
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Paint the faint overlapping arcs like the reference (sweep further across).
class _PromoArcsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final arcStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0x1A000000); // softer

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0x0D000000); // very light fill

    final clip = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    canvas.clipRRect(clip);

    // Large soft disc from left-bottom
    final discCenter = Offset(size.width * 0.18, size.height * 1.08);
    canvas.drawCircle(discCenter, size.width * 0.68, fillPaint);

    // Two sweeping arcs from top-right to center-left
    final arc1 = Rect.fromCircle(
      center: Offset(size.width * 0.75, size.height * -0.10),
      radius: size.width * 0.95,
    );
    final arc2 = Rect.fromCircle(
      center: Offset(size.width * 0.78, size.height * 0.05),
      radius: size.width * 1.15,
    );

    canvas.drawArc(arc1, 1.05, 1.25, false, arcStroke);
    canvas.drawArc(arc2, 1.05, 1.25, false, arcStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Small NFC/contactless icon built from three arcs.
class _ContactlessWaves extends StatelessWidget {
  const _ContactlessWaves({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _WavesPainter(),
    );
  }
}

class _WavesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = Colors.black87;

    for (int i = 0; i < 3; i++) {
      final r = 4.0 + i * 3.2;
      final rect =
          Rect.fromCircle(center: Offset(r + 1.5, size.height / 2), radius: r);
      canvas.drawArc(rect, -0.6, 1.2, false, p);
    }

    final dot = Paint()..color = Colors.black87;
    canvas.drawCircle(Offset(2, size.height / 2), 1.7, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PaymentRow extends StatelessWidget {
  final String title;
  final String amount;
  const _PaymentRow({required this.title, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.event_rounded, color: Colors.black87),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            Text(amount,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}

// ==========================
// Add Payment Bottom Sheet
// ==========================
class AddPaymentModal extends StatefulWidget {
  const AddPaymentModal({Key? key}) : super(key: key);

  @override
  State<AddPaymentModal> createState() => _AddPaymentModalState();
}

class _AddPaymentModalState extends State<AddPaymentModal> {
  final _amountController = TextEditingController();
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handleError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternal);
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  void _handleSuccess(PaymentSuccessResponse response) {
    if (mounted) Navigator.pop(context);
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
    FocusScope.of(context).unfocus(); // hide keyboard first
    final raw = _amountController.text.trim();
    if (raw.isEmpty) return;

    try {
      final amount = int.parse(raw) * 100; // INR → paise

      final response = await http.post(
        Uri.parse(
            'https://kirayaease-2a527d924296.herokuapp.com/create-payment-order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'receipt_id': 'rcptid_${DateTime.now().millisecondsSinceEpoch}',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to create payment order');
      }
      final data = jsonDecode(response.body);

      final options = {
        'key': 'rzp_test_v4oAPsjPGsrOQR', // TODO: replace with live key in prod
        'amount': amount,
        'currency': 'INR',
        'order_id': data['id'],
        'method': {
          'upi': true,
          'netbanking': true,
          'paylater': false,
          'card': true
        },
        'theme': {'color': '#3399cc'},
      };

      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonText = _amountController.text.isEmpty
        ? 'Pay securely'
        : 'Pay ₹${_amountController.text}';

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.95,
      minChildSize: 0.32,
      expand: false,
      builder: (context, scrollController) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                controller: scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Grab handle
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0x22000000),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Text(
                      'Make a payment',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text('Powered by Razorpay',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submitPayment(),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Enter amount',
                        prefixText: '₹ ',
                        prefixStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF4F5F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 16),
                      ),
                    ),

                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      icon: Image.asset('assets/razorpay.png',
                          height: 40, fit: BoxFit.contain),
                      onPressed: _submitPayment,
                      label: Text(buttonText),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C4FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'UPI, cards, and wallets via Razorpay Checkout.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.black54),
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
}
