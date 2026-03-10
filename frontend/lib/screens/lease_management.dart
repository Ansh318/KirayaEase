import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:ui';
import '../config/api_config.dart';

class LeasePage extends StatefulWidget {
  final String baseUrl = ApiConfig.baseUrl;

  const LeasePage({super.key});

  @override
  State<LeasePage> createState() => _LeasePageState();
}

class _LeasePageState extends State<LeasePage> {
  final List<_Lease> _leases = <_Lease>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLeasesFromApi();
  }

  Future<void> _fetchLeasesFromApi() async {
    setState(() {
      _loading = true;
      _error = null;
      _leases.clear();
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('session_id');
      if (sessionId == null || sessionId.trim().isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Please sign in to view your leases.';
        });
        return;
      }
      final response = await http.get(
        Uri.parse(ApiConfig.leasesEndpoint),
        headers: {'Authorization': 'Bearer $sessionId'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = response.body.isEmpty
            ? <dynamic>[]
            : (jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>? ?? []);
        final List<_Lease> list = [];
        for (final item in body) {
          final map = item as Map<String, dynamic>;
          list.add(_Lease.fromApiMap(map));
        }
        setState(() {
          _leases.clear();
          _leases.addAll(list);
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _loading = false;
          _error = response.statusCode == 401
              ? 'Session expired. Please sign in again.'
              : 'Failed to load leases (${response.statusCode}).';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not load leases. Please try again.';
        _leases.clear();
      });
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _fetchLeasesFromApi,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF5B6F85),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: _fetchLeasesFromApi,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
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

  Future<void> _openLeaseSidePanel(_Lease lease) async {
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Lease Preview',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, __) {
        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.88,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFDFEFF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0x2248D1CC)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 18,
                    offset: Offset(-6, 0),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined,
                            color: Color(0xFF1AAE9F)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            lease.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon:
                              const Icon(Icons.close, color: Color(0xFF6E7786)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F8FB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Rent ${lease.rentDisplay} • ${_fmtDate(lease.start)} - ${_fmtDate(lease.end)}',
                      style: const TextStyle(
                        color: Color(0xFF435365),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFFFFF), Color(0xFFF5FAFF)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x2248D1CC)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Lease PDF Preview',
                              style: TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (lease.pdfSource != null &&
                                lease.pdfSource!.trim().isNotEmpty) ...[
                              Text(
                                'Tap below to open the PDF.',
                                style: TextStyle(
                                  color: const Color(0xFF4D5F73),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _openPdfUrl(context, lease.pdfSource!),
                                  icon: const Icon(Icons.picture_as_pdf_rounded),
                                  label: const Text('Open PDF'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1A6FD4),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ] else ...[
                              const Text(
                                'No PDF attached to this lease yet.',
                                style: TextStyle(
                                  color: Color(0xFF4D5F73),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, _, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        return SlideTransition(position: slide, child: child);
      },
    );
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF8FCFF)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x2A48D1CC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 20,
            offset: Offset(0, 10),
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
                  _ActiveChip(active: isActive),
                  const SizedBox(height: 8),
                  _GlassPdfButton(onTap: () => _openLeaseSidePanel(lease)),
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
                    if (lease.rawData?['postal_code'] != null)
                      _PropertyRow('Pincode', lease.rawData!['postal_code'].toString()),
                    if (lease.rawData?['security_deposit'] != null)
                      _PropertyRow('Security deposit', lease.rawData!['security_deposit'].toString()),
                    if (lease.rawData?['lock_in_period'] != null)
                      _PropertyRow('Lock-in (months)', lease.rawData!['lock_in_period'].toString()),
                    if (lease.rawData?['due_day'] != null)
                      _PropertyRow('Rent due day', lease.rawData!['due_day'].toString()),
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

Future<void> _openPdfUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(url);
  if (uri == null) {
    messenger.showSnackBar(const SnackBar(content: Text('Invalid PDF URL.')));
    return;
  }
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not open PDF.')));
    }
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Could not open PDF.')));
  }
}

class _GlassPdfButton extends StatelessWidget {
  final VoidCallback onTap;
  const _GlassPdfButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.28),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.55)),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              size: 18,
              color: Color(0xFF1A6FD4),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  final bool active;
  const _ActiveChip({required this.active});

  @override
  Widget build(BuildContext context) {
    final bg = active ? const Color(0xFFEAFBF4) : const Color(0xFFF4F5F8);
    final fg = active ? const Color(0xFF0A8F60) : const Color(0xFF6D7480);
    final label = active ? 'Active' : 'Expired';
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.brightness_1 : Icons.schedule_rounded,
            size: active ? 8 : 12,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 11.5,
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
  final String? pdfSource;

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
    this.pdfSource,
  });

  /// Build from API response (leases by owner endpoint).
  static _Lease fromApiMap(Map<String, dynamic> map) {
    final leaseId = map['lease_id'];
    final id = leaseId != null ? leaseId.toString() : '';
    final propertyName = map['property_name']?.toString().trim();
    final addressLine1 = map['address_line1']?.toString().trim();
    final city = map['city']?.toString().trim();
    final state = map['state']?.toString().trim();
    final postalCode = map['postal_code']?.toString().trim();
    final parts = [addressLine1, city, state, postalCode]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    final propertyAddress = propertyName ??
        (parts.isEmpty ? 'Lease #$id' : parts.join(', '));
    final title = propertyName ?? addressLine1 ?? 'Lease #$id';
    final monthlyRent = map['monthly_rent'];
    final rentDisplay = monthlyRent != null
        ? _formatINR(monthlyRent is int ? monthlyRent.toString() : monthlyRent)
        : '—';
    final startStr = map['lease_start']?.toString();
    final endStr = map['lease_end']?.toString();
    return _Lease(
      id: id,
      title: title,
      rentDisplay: rentDisplay,
      start: _tryParseDate(startStr),
      end: _tryParseDate(endStr),
      verified: true,
      landlordName: null,
      landlordPhone: null,
      landlordEmail: null,
      tenantName: map['property_tenant_name']?.toString(),
      tenantPhone: null,
      propertyAddress: propertyAddress,
      rawData: map,
      pdfSource: map['pdf_url']?.toString(),
    );
  }
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

