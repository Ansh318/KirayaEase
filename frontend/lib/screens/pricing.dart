import 'package:flutter/material.dart';
import '../widgets/footer.dart';

class PricingPage extends StatelessWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final plans = [
      {
        'title': 'Basic',
        'subtitle': 'Perfect for small landlords',
        'price': 'Free',
        'features': [
          'Up to 5 properties',
          'Basic rent collection',
          'Tenant screening',
          'Monthly reports',
          'Email support',
        ],
        'highlight': false,
        'buttonColor': const Color(0xFF00C6A6),
      },
      {
        'title': 'Pro',
        'subtitle': 'Ideal for growing portfolios',
        'price': '₹49 /month',
        'features': [
          'Up to 25 properties',
          'Advanced rent collection',
          'Comprehensive tenant screening',
          'Real-time analytics',
          'Expense tracking',
          'Priority support',
          'Mobile app access',
        ],
        'highlight': true,
        'buttonColor': const Color(0xFF00C6A6),
      },
      {
        'title': 'Enterprise',
        'subtitle': 'For large property managers',
        'price': '₹99 /month',
        'features': [
          'Unlimited properties',
          'White-label solution',
          'Custom integrations',
          'Advanced reporting',
          'Dedicated account manager',
          '24/7 phone support',
          'API access',
          'Custom workflows',
        ],
        'highlight': false,
        'buttonColor': const Color(0xFF00C6A6),
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFEFFFFD),
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Simple, transparent pricing for landlords and property managers of all sizes',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            ...plans.map((plan) {
              final isPro = plan['highlight'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        isPro ? const Color(0xFF00C6A6) : Colors.grey.shade300,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (isPro)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C6A6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          '★ Most Popular',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      plan['title'] as String,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan['subtitle'] as String,
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      plan['price'] as String,
                      style: const TextStyle(
                          fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Column(
                      children:
                          (plan['features'] as List<String>).map((feature) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.check_circle,
                                  color: Color(0xFF00C6A6), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(feature,
                                      style: const TextStyle(fontSize: 15))),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: plan['buttonColor'] as Color,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/login');
                        },
                        child: const Text(
                          'Get Started',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            const Footer()
          ],
        ),
      ),
    );
  }
}
