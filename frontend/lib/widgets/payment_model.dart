import 'package:flutter/material.dart';

class AddPaymentModal extends StatefulWidget {
  const AddPaymentModal({super.key});

  @override
  State<AddPaymentModal> createState() => _AddPaymentModalState();
}

class _AddPaymentModalState extends State<AddPaymentModal>
    with SingleTickerProviderStateMixin {
  final _upiController = TextEditingController();
  final _amountController = TextEditingController();

  final _debitNameController = TextEditingController();
  final _debitNumberController = TextEditingController();
  final _debitExpiryController = TextEditingController();
  final _debitCvvController = TextEditingController();
  final _debitAmountController = TextEditingController();

  final _creditNameController = TextEditingController();
  final _creditNumberController = TextEditingController();
  final _creditExpiryController = TextEditingController();
  final _creditCvvController = TextEditingController();
  final _creditAmountController = TextEditingController();

  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _upiController.dispose();
    _amountController.dispose();

    _debitNameController.dispose();
    _debitNumberController.dispose();
    _debitExpiryController.dispose();
    _debitCvvController.dispose();
    _debitAmountController.dispose();

    _creditNameController.dispose();
    _creditNumberController.dispose();
    _creditExpiryController.dispose();
    _creditCvvController.dispose();
    _creditAmountController.dispose();

    _tabController.dispose();
    super.dispose();
  }

  void _submitUPI() {
    if (_upiController.text.isEmpty || _amountController.text.isEmpty) return;
    // TODO: kick off UPI payment
    Navigator.pop(context);
  }

  void _submitCard(bool isDebit) {
    final name =
        isDebit ? _debitNameController.text : _creditNameController.text;
    final number =
        isDebit ? _debitNumberController.text : _creditNumberController.text;
    final expiry =
        isDebit ? _debitExpiryController.text : _creditExpiryController.text;
    final cvv = isDebit ? _debitCvvController.text : _creditCvvController.text;
    final amount =
        isDebit ? _debitAmountController.text : _creditAmountController.text;

    if ([name, number, expiry, cvv, amount].any((s) => s.isEmpty)) return;
    // TODO: kick off card payment
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header
            Text(
              "₹ Add Payment Method",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge!
                  .copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Choose how you'd like to pay",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // Tabs
            TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.lightBlue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.black54,
              tabs: const [
                Tab(icon: Icon(Icons.qr_code), text: "UPI"),
                Tab(icon: Icon(Icons.credit_card), text: "Debit"),
                Tab(icon: Icon(Icons.credit_card_outlined), text: "Credit"),
              ],
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // UPI Tab
                  ListView(
                    controller: ctrl,
                    children: [
                      Center(
                        child: Text(
                          "Pay via UPI",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _upiController,
                        decoration: const InputDecoration(
                          labelText: "UPI ID",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountController,
                        decoration: const InputDecoration(
                          labelText: "Amount (₹)",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _submitUPI,
                          child: Text(
                            "Pay ₹${_amountController.text.isEmpty ? '0' : _amountController.text}",
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Debit Card Tab
                  ListView(
                    controller: ctrl,
                    children: [
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _debitNameController,
                        decoration: const InputDecoration(
                          labelText: "Name on Card",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _debitNumberController,
                        decoration: const InputDecoration(
                          labelText: "Card Number",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _debitExpiryController,
                              decoration: const InputDecoration(
                                labelText: "MM/YY",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _debitCvvController,
                              decoration: const InputDecoration(
                                labelText: "CVV",
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _debitAmountController,
                        decoration: const InputDecoration(
                          labelText: "Amount (₹)",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _submitCard(true),
                          child: Text(
                            "Pay ₹${_debitAmountController.text.isEmpty ? '0' : _debitAmountController.text}",
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Credit Card Tab
                  ListView(
                    controller: ctrl,
                    children: [
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _creditNameController,
                        decoration: const InputDecoration(
                          labelText: "Name on Card",
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _creditNumberController,
                        decoration: const InputDecoration(
                          labelText: "Card Number",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _creditExpiryController,
                              decoration: const InputDecoration(
                                labelText: "MM/YY",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _creditCvvController,
                              decoration: const InputDecoration(
                                labelText: "CVV",
                                border: OutlineInputBorder(),
                              ),
                              obscureText: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _creditAmountController,
                        decoration: const InputDecoration(
                          labelText: "Amount (₹)",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _submitCard(false),
                          child: Text(
                            "Pay ₹${_creditAmountController.text.isEmpty ? '0' : _creditAmountController.text}",
                          ),
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
    );
  }
}
