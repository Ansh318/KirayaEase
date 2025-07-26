// lib/screens/landing_page.dart

import 'package:flutter/material.dart';
import '../widgets/base_scaffold.dart';
import '../widgets/footer.dart';

/// Simple data model for one step
class StepData {
  final String title;
  final String desc;
  StepData({required this.title, required this.desc});
}

/// A slick, interactive card for each step
class StepCard extends StatefulWidget {
  final int index;
  final StepData data;
  const StepCard({super.key, required this.index, required this.data});

  @override
  _StepCardState createState() => _StepCardState();
}

class _StepCardState extends State<StepCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final primary = const Color(0xFF00C6A6);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedScale(
        scale: _hovering ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Card(
          elevation: _hovering ? 8 : 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.hardEdge,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: primary,
                      child: Text(
                        '${widget.index}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.data.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.data.desc,
                  style: TextStyle(color: Colors.black.withOpacity(0.7)),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: 1.0,
                    minHeight: 4,
                    backgroundColor: primary.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation(primary),
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

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      StepData(
        title: 'Sign up and create your schedule',
        desc:
            "We'll perform a soft credit check… then create a rent schedule that fits your finances.",
      ),
      StepData(
        title: 'Pay part of your rent up front',
        desc:
            'We use your 1st payment + credit line to pay your full rent on time. Auto‑pull or manual, you decide.',
      ),
      StepData(
        title: 'Your rent gets paid',
        desc:
            'Depending on your property, we either pay directly or give you a portal link to submit rent.',
      ),
      StepData(
        title: 'Pay us back on your schedule',
        desc:
            'Auto‑process according to your plan, or pay on‑demand via the app—totally up to you.',
      ),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    // lowered breakpoint from 1000 to 800 for side‑by‑side layout
    final isTwoCol = screenWidth > 800;
    final horizontalPadding = 24.0;
    final cardWidth = isTwoCol
        ? (screenWidth - (horizontalPadding * 2) - 20) / 2
        : screenWidth - horizontalPadding * 2;

    return BaseScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 40),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFA6F0EB), Color(0xFFC2F4FB)],
            ),
          ),
          child: Column(
            children: [
              // 🔄 Slick step‑cards + phone mockup
              Container(
                margin: const EdgeInsets.only(top: 60, bottom: 40),
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: isTwoCol
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LEFT: two‑column grid of cards
                          Expanded(
                            flex: 3,
                            child: Wrap(
                              spacing: 20,
                              runSpacing: 20,
                              children: List.generate(steps.length, (i) {
                                return SizedBox(
                                  width: cardWidth,
                                  child: StepCard(
                                    index: i + 1,
                                    data: steps[i],
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(width: 20),

                          // RIGHT: iPhone mockup
                          Expanded(
                            flex: 2,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.001)
                                ..rotateY(-0.3)
                                ..rotateX(0.02),
                              child: Image.asset(
                                'assets/rent_mockup.png',
                                width: 300,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          // steps stacked
                          Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: horizontalPadding),
                            child: Column(
                              children: List.generate(steps.length, (i) {
                                return StepCard(index: i + 1, data: steps[i]);
                              }),
                            ),
                          ),
                          const SizedBox(height: 40),
                          // phone mockup
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(-0.3)
                              ..rotateX(0.02),
                            child: Image.asset(
                              'assets/rent_mockup.png',
                              width: 220,
                            ),
                          ),
                        ],
                      ),
              ),

              // 🧠 CTA
              Container(
                width: screenWidth > 800 ? 1000 : double.infinity,
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.only(bottom: 40),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Rent Simple. Live Easy.",
                      style: TextStyle(
                        fontSize: 70,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Whether you're a landlord managing a single unit or a growing portfolio—or a tenant navigating monthly rent—KirayaEase empowers you with the insight and flexibility to get the most out of every square foot.",
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'OpenSans',
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pushNamed(context, '/login');
                          },
                          child: const Text(
                            "Get Started",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            // TODO: add Learn more logic
                          },
                          child: const Text(
                            "Learn more",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ✅ Footer
              const Footer(),
            ],
          ),
        ),
      ),
    );
  }
}
