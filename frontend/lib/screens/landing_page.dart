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
  State<StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<StepCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF00C6A6);

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
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.data.desc,
                  style: TextStyle(
                    color: Colors.black.withOpacity(0.7),
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: 1.0,
                    minHeight: 4,
                    backgroundColor: primary.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation(primary),
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
        title: 'Connect your lease.',
        desc:
            'AI reads your lease details, rent cycle, and tenant info to create a live rent system.',
      ),
      StepData(
        title: 'AI runs the rent cycle',
        desc:
            'Our AI tracks due dates, nudges tenants, flags issues & provide insights to increase rental income.',
      ),
      StepData(
        title: 'Rent gets paid on time, everytime',
        desc: 'Smart reminders keep every rent payment on schedule.',
      ),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isTwoCol = screenWidth > 800;
    const horizontalPadding = 24.0;
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
              const SizedBox(height: 60),

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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompactHero = constraints.maxWidth < 430;
                        final titleSize = isCompactHero ? 52.0 : 64.0;
                        final subtitleSize = isCompactHero ? 16.0 : 24.0;

                        return Column(
                          children: [
                            Text(
                              "RentOS",
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                height: 1.0,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                "AI For The Everyday Landlord",
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: subtitleSize,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 430;
                        final buttonStyle = ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        );

                        const maxButtonWidth = 200.0;
                        if (isCompact) {
                          return Column(
                            children: [
                              Center(
                                child: SizedBox(
                                  width: maxButtonWidth,
                                  child: ElevatedButton(
                                    style: buttonStyle,
                                    onPressed: () {
                                      Navigator.pushNamed(context, '/login');
                                    },
                                    child: const Text(
                                      "Sign in",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }

                        return Center(
                          child: SizedBox(
                            width: maxButtonWidth,
                            child: ElevatedButton(
                              style: buttonStyle,
                              onPressed: () {
                                Navigator.pushNamed(context, '/login');
                              },
                              child: const Text(
                                "Sign in",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const Text(
                "How does it work?",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                  letterSpacing: -0.5,
                  height: 1.2,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 30),

              // 🔄 Slick step-cards + phone mockup
              Container(
                margin: const EdgeInsets.only(bottom: 40),
                padding:
                    const EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: isTwoCol
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Wrap(
                              spacing: 20,
                              runSpacing: 32, // increased vertical spacing
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
                                width: 400,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: horizontalPadding),
                            child: Column(
                              children: List.generate(steps.length, (i) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      bottom: 28.0), // more spacing
                                  child: StepCard(index: i + 1, data: steps[i]),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 40),
                          Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, 0.001)
                              ..rotateY(-0.3)
                              ..rotateX(0.02),
                            child: Image.asset(
                              'assets/rent_mockup.png',
                              width: 280,
                            ),
                          ),
                        ],
                      ),
              ),

              const Footer(),
            ],
          ),
        ),
      ),
    );
  }
}
