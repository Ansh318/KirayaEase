import 'package:flutter/material.dart';
import '../widgets/footer.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFE9FCFB);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text(
          'FAQ',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Quick answers for landlords using KirayaEase.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 24),
                  _FaqItem(
                    question: 'How do I add a new lease?',
                    answer:
                        'Go to the Home screen and tap “Review lease”. Upload your PDF and follow the prompts. We automatically extract key details and create the lease card for you.',
                  ),
                  _FaqItem(
                    question: 'Where can I see all my leases?',
                    answer:
                        'Open Settings → “Lease manager”. You will see all active and past leases, along with rent, dates, tenant name, and the attached PDF.',
                  ),
                  _FaqItem(
                    question: 'How do I view the lease PDF?',
                    answer:
                        'On the Lease manager screen, tap “View Lease” on a card. If a PDF is attached, it opens directly inside the app.',
                  ),
                  _FaqItem(
                    question: 'A tenant paid rent – how do I confirm it?',
                    answer:
                        'In the chat, say something like “he paid for March”. The assistant will mark that month as paid and it will show up in the Payments section.',
                  ),
                  _FaqItem(
                    question: 'Can I delete a lease?',
                    answer:
                        'Yes. Open Settings → “Lease manager”, tap “View Lease”, and use the delete icon in the top-right of the drawer.',
                  ),
                  _FaqItem(
                    question: 'What happens if I sign out?',
                    answer:
                        'Your data stays safe. When you sign in again with the same Google account, your properties, leases, and payments are restored.',
                  ),
                  SizedBox(height: 40),
                  Footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({
    required this.question,
    required this.answer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF4B5563),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

