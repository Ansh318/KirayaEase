import 'package:flutter/material.dart';
import '../widgets/footer.dart';
import 'tenant_info.dart';

class LandlordInfo extends StatelessWidget {
  const LandlordInfo({super.key});

  static const Color kBg = TenantInfo.kBg;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text(
          "Landlord Info",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            SizedBox(height: 24),
            _LandlordInfoSection(),
            SizedBox(height: 48),
            Footer(),
          ],
        ),
      ),
    );
  }
}

class _LandlordInfoSection extends StatelessWidget {
  const _LandlordInfoSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: const Column(
            children: [
              Text(
                "AI for the Everyday Landlord",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                "RentOS manages your rent end-to-end — so you don't have to.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            BenefitCard.numbered(
              number: 1,
              title: "Get Your Time Back",
              desc:
                  "No chasing tenants. No manual reminders. RentOS handles collections automatically.",
            ),
            BenefitCard.numbered(
              number: 2,
              title: "Prevent Costly Surprises",
              desc:
                  "Spot late-payment risks and vacancy issues before they hurt your cash flow.",
            ),
            BenefitCard.numbered(
              number: 3,
              title: "Only Step In When Necessary",
              desc:
                  "Receive alerts only when your intervention is truly required.",
            ),
            BenefitCard.numbered(
              number: 4,
              title: "Earn More From Every Property",
              desc:
                  "Smarter renewal pricing and lease decisions that increase net yield.",
            ),
          ],
        ),
      ],
    );
  }
}
