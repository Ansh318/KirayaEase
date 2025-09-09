import 'package:flutter/material.dart';
import '../widgets/base_scaffold.dart';
import '../widgets/footer.dart';
import '../widgets/onboarding_form.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BaseScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OnboardingForm(),
            SizedBox(height: 40),
            Footer(),
          ],
        ),
      ),
    );
  }
}
