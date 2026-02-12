import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../services/lease_store.dart';

class LeasePage extends StatefulWidget {
  final String baseUrl = ApiConfig.baseUrl;

  const LeasePage({super.key});

  @override
  State<LeasePage> createState() => _LeasePageState();
}

class _LeasePageState extends State<LeasePage> {
  final LeaseStore _leaseStore = LeaseStore();
  final List<_Lease> _leases = <_Lease>[];

  @override
  void initState() {
    super.initState();
    _initializeLeases();
    // Listen to lease store changes
    _leaseStore.addListener(_onLeaseStoreChanged);
  }

  @override
  void dispose() {
    _leaseStore.removeListener(_onLeaseStoreChanged);
    super.dispose();
  }

  void _onLeaseStoreChanged() {
    _loadLeasesFromStore();
  }

  Future<void> _initializeLeases() async {
    await _leaseStore.initialize();
    _loadLeasesFromStore();
  }

  void _loadLeasesFromStore() {
    setState(() {
      _leases.clear();
      _leases.addAll(
        _leaseStore.leases.map((leaseData) => _Lease(
          id: leaseData.id,
          title: leaseData.propertyAddress.split('\n').first.trim(),
          rentDisplay: _formatINR(leaseData.rentAmount),
          start: _tryParseDate(leaseData.startDate),
          end: _tryParseDate(leaseData.endDate),
          verified: true,
          landlordName: leaseData.landlordName,
          landlordPhone: leaseData.landlordPhone,
          landlordEmail: leaseData.landlordEmail,
          tenantName: leaseData.tenantName,
          tenantPhone: leaseData.tenantPhone,
          propertyAddress: leaseData.propertyAddress,
          rawData: leaseData.rawData,
        )),
      );
    });
  }



  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F7F8),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: const Text(
          'Leases',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.black,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _leases.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _LeaseCard(lease: _leases[i]),
      ),
    );
  }
}

// ===== Widgets =====

class _LeaseCard extends StatefulWidget {
  final _Lease lease;
  const _LeaseCard({required this.lease});

  @override
  State<_LeaseCard> createState() => _LeaseCardState();
}

class _LeaseCardState extends State<_LeaseCard> {
  bool _isExpanded = false;

  bool get isActive {
    final now = DateTime.now();
    if (widget.lease.end == null) return false;
    // Active if end date is today or in the future
    return !widget.lease.end!.isBefore(DateTime(now.year, now.month, now.day));
  }

  @override
  Widget build(BuildContext context) {
    final lease = widget.lease;
    final dateStyle = TextStyle(
      color: Colors.black.withOpacity(0.7),
      fontSize: 13, // smaller rent & dates as in your mock
      height: 1.25,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E6E9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left block: Title + dates
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      lease.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Rent: ${lease.rentDisplay}', style: dateStyle),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmtDate(lease.start)} – ${_fmtDate(lease.end)}',
                      style: dateStyle,
                    ),
                  ],
                ),
              ),

              // Right block: verified badge + status line below it
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const _VerifiedBadge(),
                  const SizedBox(height: 8),
                  _StatusLine(active: isActive),
                ],
              ),
            ],
          ),
          
          // Expandable Properties section
          if (lease.rawData != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Row(
                children: [
                  Text(
                    'Properties',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
            ),
            if (_isExpanded) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (lease.landlordName != null)
                      _PropertyRow('Landlord', lease.landlordName!),
                    if (lease.landlordPhone != null)
                      _PropertyRow('Landlord Phone', lease.landlordPhone!),
                    if (lease.landlordEmail != null)
                      _PropertyRow('Landlord Email', lease.landlordEmail!),
                    if (lease.tenantName != null)
                      _PropertyRow('Tenant', lease.tenantName!),
                    if (lease.tenantPhone != null)
                      _PropertyRow('Tenant Phone', lease.tenantPhone!),
                    if (lease.propertyAddress != null && lease.propertyAddress != lease.title)
                      _PropertyRow('Property Address', lease.propertyAddress!),
                    if (lease.rawData?['property_pincode'] != null)
                      _PropertyRow('Pincode', lease.rawData!['property_pincode'].toString()),
                    if (lease.rawData?['aadhar'] != null)
                      _PropertyRow('Aadhar', lease.rawData!['aadhar'].toString()),
                    if (lease.rawData?['pan'] != null)
                      _PropertyRow('PAN', lease.rawData!['pan'].toString()),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// EXACT status line per screenshot:
/// - If active: small green dot + "Active" in black.
/// - If expired: just "Expired" in black (no dot).
class _StatusLine extends StatelessWidget {
  final bool active;
  const _StatusLine({required this.active});

  @override
  Widget build(BuildContext context) {
    if (active) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF19C37D), // green dot
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          const Text(
            'Active',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: -0.1,
            ),
          ),
        ],
      );
    }
    return const Text(
      'Expired',
      style: TextStyle(
        color: Colors.black,
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: -0.1,
      ),
    );
  }
}

/// Meta-style blue tick
class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF1877F2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 15,
            height: 15,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1877F2), // Meta blue
            ),
            child: const Icon(Icons.check, size: 14, color: Colors.white),
          ),
          const SizedBox(width: 6),
          const Text(
            'Verified',
            style: TextStyle(
              color: Color(0xFF1877F2),
              fontWeight: FontWeight.w700,
              fontSize: 10,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Property Row Widget =====
class _PropertyRow extends StatelessWidget {
  final String label;
  final String value;

  const _PropertyRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Model & helpers =====

class _Lease {
  final String id;
  final String title;
  final String rentDisplay;
  final DateTime? start;
  final DateTime? end;
  final bool verified;
  final String? landlordName;
  final String? landlordPhone;
  final String? landlordEmail;
  final String? tenantName;
  final String? tenantPhone;
  final String? propertyAddress;
  final Map<String, dynamic>? rawData;

  _Lease({
    required this.id,
    required this.title,
    required this.rentDisplay,
    required this.start,
    required this.end,
    required this.verified,
    this.landlordName,
    this.landlordPhone,
    this.landlordEmail,
    this.tenantName,
    this.tenantPhone,
    this.propertyAddress,
    this.rawData,
  });

}

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

DateTime? _tryParseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  if (v is int) {
    // epoch ms or seconds
    if (v > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(v);
    return DateTime.fromMillisecondsSinceEpoch(v * 1000);
  }
  if (v is String) {
    try {
      return DateTime.parse(v);
    } catch (_) {
      return null;
    }
  }
  return null;
}

String _formatINR(dynamic amount) {
  if (amount == null) return '—';
  try {
    final num a = (amount is String) ? num.parse(amount) : amount as num;
    return '₹${a.toStringAsFixed(0)}';
  } catch (_) {
    return '₹$amount';
  }
}

