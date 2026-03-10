import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final List<_Payment> _payments = <_Payment>[];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchPaymentsFromApi();
  }

  Future<void> _fetchPaymentsFromApi() async {
    setState(() {
      _loading = true;
      _error = null;
      _payments.clear();
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('session_id');
      if (sessionId == null || sessionId.trim().isEmpty) {
        setState(() {
          _loading = false;
          _error = 'Please sign in to view your payments.';
        });
        return;
      }
      final response = await http.get(
        Uri.parse(ApiConfig.paymentsEndpoint),
        headers: {'Authorization': 'Bearer $sessionId'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> body = response.body.isEmpty
            ? <dynamic>[]
            : (jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>? ?? []);
        final List<_Payment> list = [];
        for (final item in body) {
          final map = item as Map<String, dynamic>;
          list.add(_Payment.fromApiMap(map));
        }
        setState(() {
          _payments.clear();
          _payments.addAll(list);
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _loading = false;
          _error = response.statusCode == 401
              ? 'Session expired. Please sign in again.'
              : 'Failed to load payments (${response.statusCode}).';
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not load payments. Please try again.';
        _payments.clear();
      });
    }
  }

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
          'Payments',
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
            onPressed: _loading ? null : _fetchPaymentsFromApi,
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
                          onPressed: _fetchPaymentsFromApi,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _payments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.payments_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No payments yet',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rent confirmations will appear here.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: _payments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _PaymentCard(payment: _payments[i]),
                    ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final _Payment payment;

  const _PaymentCard({required this.payment});

  @override
  Widget build(BuildContext context) {
    final isConfirmed = (payment.status ?? '').toLowerCase() == 'confirmed';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.propertyName,
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
                    Text(
                      _formatMonth(payment.month),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black.withOpacity(0.65),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatINR(payment.amount),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A6FD4),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(confirmed: isConfirmed),
            ],
          ),
          if (payment.confirmedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              'Confirmed ${_formatDate(payment.confirmedAt!)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatMonth(String? monthStr) {
    if (monthStr == null || monthStr.isEmpty) return '—';
    try {
      final d = DateTime.parse(monthStr);
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return monthStr;
    }
  }

  static String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day}/${d.month}/${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  static String _formatINR(dynamic amount) {
    if (amount == null) return '—';
    try {
      final num a = (amount is String) ? num.parse(amount) : amount as num;
      return '₹${a.toStringAsFixed(0)}';
    } catch (_) {
      return '₹$amount';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final bool confirmed;

  const _StatusChip({required this.confirmed});

  @override
  Widget build(BuildContext context) {
    final bg = confirmed ? const Color(0xFFEAFBF4) : const Color(0xFFFEF8E8);
    final fg = confirmed ? const Color(0xFF0A8F60) : const Color(0xFFB8860B);
    final label = confirmed ? 'Confirmed' : 'Pending';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            confirmed ? Icons.check_circle : Icons.schedule,
            size: 14,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Payment {
  final String id;
  final String? leaseId;
  final String propertyName;
  final String? month;
  final int? amount;
  final String? status;
  final String? confirmedAt;
  final int? monthlyRent;

  _Payment({
    required this.id,
    this.leaseId,
    required this.propertyName,
    this.month,
    this.amount,
    this.status,
    this.confirmedAt,
    this.monthlyRent,
  });

  static _Payment fromApiMap(Map<String, dynamic> map) {
    final confId = map['confirmation_id'] ?? map['id'];
    final id = confId?.toString() ?? '';
    final amount = map['amount'];
    final amt = amount is int ? amount : (amount is num ? amount.toInt() : null);
    return _Payment(
      id: id,
      leaseId: map['lease_id']?.toString(),
      propertyName: map['property_name']?.toString().trim() ?? 'Property',
      month: map['month']?.toString(),
      amount: amt,
      status: map['payment_status']?.toString() ?? map['status']?.toString(),
      confirmedAt: map['confirmed_at']?.toString(),
      monthlyRent: map['monthly_rent'] is int
          ? map['monthly_rent'] as int
          : (map['monthly_rent'] is num ? (map['monthly_rent'] as num).toInt() : null),
    );
  }
}
