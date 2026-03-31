// tenant_dashboard_v2.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import '../route_observer.dart';
import '../services/lease_store.dart';
import '../widgets/landlord_home_coach.dart';
import 'docuseal_signing_webview_page.dart';
import 'lease_agreement_wizard_page.dart';
// import '../widgets/ai_assistant.dart';

class TenantDashboardV2 extends StatefulWidget {
  const TenantDashboardV2({super.key});

  @override
  State<TenantDashboardV2> createState() => _TenantDashboardV2State();
}

/// One option in the landlord context selector: Portfolio or a specific property.
class _PropertyContextOption {
  final String id;
  final String label;
  final String scope; // 'portfolio' | 'property'
  final Map<String, dynamic>? propertyData;

  const _PropertyContextOption({
    required this.id,
    required this.label,
    required this.scope,
    this.propertyData,
  });
}

class _TenantDashboardV2State extends State<TenantDashboardV2>
    with RouteAware {
  final Color bgColor = const Color(0xFFCBF8F3);
  String? userName;
  String _userRole = 'tenant';
  String _activeScope = 'self'; // self | portfolio | property
  String? _activePropertyId;
  List<_PropertyContextOption> _propertyContexts = const [];
  bool isLoading = true;
  bool _landlordEmptyPortfolioBannerDismissed = false;

  static const _kLandlordEmptyBannerPrefsKey =
      'kirayaease_landlord_workflow_banner_dismissed';

  int get _landlordLeaseCount =>
      _propertyContexts.where((c) => c.scope == 'property').length;

  // Chat state
  final List<Map<String, dynamic>> messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSendingMessage = false;
  bool _isUploadingFile = false;

  // Conversation memory - store session ID for maintaining context
  String _sessionId = "default";

  // File state - store selected file until user sends
  String? _selectedFilePath;
  String? _selectedFileName;

  // Razorpay instance for payment widget
  Razorpay? _razorpay;

  Map<String, dynamic> _decodeJsonMap(http.Response response) {
    final decodedBody = utf8.decode(response.bodyBytes);
    final parsed = jsonDecode(decodedBody);
    if (parsed is Map<String, dynamic>) return parsed;
    if (parsed is Map) return parsed.cast<String, dynamic>();
    return <String, dynamic>{};
  }

  String _sanitizeAiText(String text) {
    var t = text
        .replaceAll('â¹', '₹')
        .replaceAll('Â₹', '₹')
        .replaceAll('â', '-')
        .replaceAll('â', "'")
        .replaceAll('â', '"')
        .replaceAll('â', '"');
    // `[label](url)` → label only — assistant URLs are often unusable in-app (embeds, auth, etc.).
    t = t.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]*\)'),
      (m) => m.group(1) ?? '',
    );
    // Angle-bracket autolinks `<https://...>` → remove URL entirely
    t = t.replaceAll(RegExp(r'<https?://[^>\s]+>'), '');
    return t;
  }

  String? _pickDocusealLandlordUrl(Map<String, dynamic> payload) {
    final embedsRaw = payload['docuseal_submitter_embeds'];
    if (embedsRaw is Map) {
      final landlord = embedsRaw['Landlord'] ?? embedsRaw['landlord'];
      if (landlord != null && landlord.toString().trim().isNotEmpty) {
        return landlord.toString().trim();
      }
    }
    final submitters = payload['submitters'];
    if (submitters is List) {
      for (final s in submitters) {
        if (s is Map) {
          final role = (s['role'] ?? '').toString().trim().toLowerCase();
          final embed = (s['embed_src'] ?? '').toString().trim();
          if (role == 'landlord' && embed.isNotEmpty) return embed;
        }
      }
    }
    final fallback = (payload['docuseal_signing_url'] ?? '').toString().trim();
    return fallback.isEmpty ? null : fallback;
  }

  @override
  void initState() {
    super.initState();
    // Generate a unique session ID for this conversation
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _loadRoleAndContext();
    fetchUserName();

    // Initialize Razorpay
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handlePaymentExternal);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is ModalRoute<void>) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _razorpay?.clear();
    _razorpay = null;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // User returned to this screen (e.g. from lease manager); refresh context so deleted leases are reflected.
    _loadRoleAndContext();
  }

  Future<bool> _verifyPaymentOnServer(PaymentSuccessResponse response) async {
    final orderId = response.orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (orderId == null || paymentId == null || signature == null) {
      return false;
    }

    final verifyRes = await http.post(
      Uri.parse(ApiConfig.verifyPaymentEndpoint),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'order_id': orderId,
        'payment_id': paymentId,
        'signature': signature,
      }),
    );
    if (verifyRes.statusCode != 200) return false;
    final payload = _decodeJsonMap(verifyRes);
    return payload['success'] == true;
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final verified = await _verifyPaymentOnServer(response);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          verified ? 'Payment successful!' : 'Payment verification failed.',
        ),
      ),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}')),
    );
  }

  void _handlePaymentExternal(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet: ${response.walletName}')),
    );
  }

  Future<void> _loadRoleAndContext() async {
    final prefs = await SharedPreferences.getInstance();
    final role = (prefs.getString('user_role') ?? 'tenant').toLowerCase();
    final savedScope = prefs.getString('active_scope');
    final savedPropertyId = prefs.getString('active_property_id');
    final emptyBannerDismissed =
        prefs.getBool(_kLandlordEmptyBannerPrefsKey) == true;

    List<_PropertyContextOption> contexts = const [];
    if (role == 'landlord') {
      contexts = await _buildLandlordPropertyContexts();
    }

    if (!mounted) return;
    setState(() {
      _landlordEmptyPortfolioBannerDismissed = emptyBannerDismissed;
      _userRole = role == 'landlord' ? 'landlord' : 'tenant';
      if (_userRole == 'landlord') {
        _propertyContexts = contexts;
        if (savedScope == 'property' &&
            savedPropertyId != null &&
            contexts.any((item) => item.id == savedPropertyId)) {
          _activeScope = 'property';
          _activePropertyId = savedPropertyId;
        } else {
          _activeScope = 'portfolio';
          _activePropertyId = null;
        }
      } else {
        _activeScope = 'self';
        _activePropertyId = null;
        _propertyContexts = const [];
      }
    });
    if (role == 'landlord') {
      _scheduleLandlordHomeCoach();
    }
  }

  void _scheduleLandlordHomeCoach() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await showLandlordHomeCoachIfNeeded(context);
    });
  }

  Future<void> _dismissLandlordEmptyPortfolioBanner() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLandlordEmptyBannerPrefsKey, true);
    if (mounted) {
      setState(() => _landlordEmptyPortfolioBannerDismissed = true);
    }
  }

  /// Fetches context options from the leases API so the list reflects current leases.
  /// When a lease is deleted, it no longer appears here.
  Future<List<_PropertyContextOption>> _buildLandlordPropertyContexts() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null || sessionId.trim().isEmpty) {
      return _defaultPropertyContexts();
    }
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.leasesEndpoint),
        headers: {'Authorization': 'Bearer $sessionId'},
      );
      if (response.statusCode != 200) return _defaultPropertyContexts();
      final List<dynamic> body = response.body.isEmpty
          ? <dynamic>[]
          : (jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>? ?? []);
      final contexts = <_PropertyContextOption>[
        const _PropertyContextOption(
          id: 'portfolio',
          label: 'Portfolio (All Properties)',
          scope: 'portfolio',
        ),
      ];
      for (final item in body) {
        final map = item as Map<String, dynamic>;
        final leaseId = map['lease_id'];
        final propertyId = map['property_id'];
        final name = map['property_name']?.toString().trim() ??
            map['address_line1']?.toString().trim() ??
            'Lease #$leaseId';
        if (leaseId == null) continue;
        // Use lease_id as id so deleting a lease removes it from the list.
        contexts.add(
          _PropertyContextOption(
            id: leaseId.toString(),
            label: name,
            scope: 'property',
            propertyData: {
              'id': propertyId,
              'name': map['property_name'],
              'tenant_name': map['property_tenant_name'],
              'tenant_email': map['tenant_email'],
              'tenant_phone': map['tenant_phone'],
              'address_line1': map['address_line1'],
              'city': map['city'],
              'state': map['state'],
              'postal_code': map['postal_code'],
            },
          ),
        );
      }
      return contexts;
    } catch (_) {
      return _defaultPropertyContexts();
    }
  }

  List<_PropertyContextOption> _defaultPropertyContexts() => [
        const _PropertyContextOption(
          id: 'portfolio',
          label: 'Portfolio (All Properties)',
          scope: 'portfolio',
        ),
      ];

  Future<void> _onContextChanged(_PropertyContextOption selected) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('active_scope', selected.scope);
    if (selected.scope == 'property') {
      await prefs.setString('active_property_id', selected.id);
    } else {
      await prefs.remove('active_property_id');
    }

    if (!mounted) return;
    setState(() {
      _activeScope = selected.scope;
      _activePropertyId = selected.scope == 'property' ? selected.id : null;
    });
  }

  String _activeContextLabel() {
    if (_userRole != 'landlord') return 'Property context';
    if (_activeScope == 'portfolio') return 'Portfolio (All Properties)';
    final selected = _propertyContexts.where((p) => p.id == _activePropertyId);
    if (selected.isEmpty) return 'Property context';
    return selected.first.label;
  }

  String? _inferLocalityFromText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final lower = text.toLowerCase();
    if (lower.contains('juhu')) return 'juhu';
    if (lower.contains('bandra')) return 'bandra';
    if (lower.contains('mahim')) return 'mahim';
    return null;
  }

  int? _extractBhkFromText(String? text) {
    if (text == null) return null;
    final match =
        RegExp(r'([2-4])\s*bhk', caseSensitive: false).firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  /// Build property_context for the agent when a specific property is selected.
  Future<Map<String, dynamic>> _buildPropertyContextForChat() async {
    if (_userRole != 'landlord' || _activeScope != 'property' || _activePropertyId == null) {
      return {};
    }
    final selected = _propertyContexts.where((p) => p.id == _activePropertyId);
    if (selected.isEmpty || selected.first.propertyData == null) return {};
    final data = selected.first.propertyData!;
    return {
      "property_id": data['id'],
      "name": data['name']?.toString(),
      "property_name": data['name']?.toString(),
      "tenant_name": data['tenant_name']?.toString(),
      "tenant_email": data['tenant_email']?.toString(),
      "tenant_phone": data['tenant_phone']?.toString(),
      "address_line1": data['address_line1']?.toString(),
      "city": data['city']?.toString(),
      "state": data['state']?.toString(),
      "postal_code": data['postal_code']?.toString(),
    };
  }

  _PropertyContextOption _selectedContextOrFallback() {
    if (_activeScope == 'property' && _activePropertyId != null) {
      for (final option in _propertyContexts) {
        if (option.id == _activePropertyId && option.scope == 'property') {
          return option;
        }
      }
    }

    for (final option in _propertyContexts) {
      if (option.scope == 'portfolio') return option;
    }

    return const _PropertyContextOption(
      id: 'portfolio',
      label: 'Portfolio (All Properties)',
      scope: 'portfolio',
    );
  }

  Future<void> _showContextPickerSheet() async {
    // Refresh from backend so deleted leases are immediately reflected.
    final contexts = await _buildLandlordPropertyContexts();
    if (!mounted) return;
    final previouslySelectedId = _activeScope == 'property' ? _activePropertyId : null;
    final stillPresent = previouslySelectedId != null &&
        contexts.any((c) => c.scope == 'property' && c.id == previouslySelectedId);
    setState(() {
      _propertyContexts = contexts;
      if (!stillPresent && previouslySelectedId != null) {
        _activeScope = 'portfolio';
        _activePropertyId = null;
      }
    });
    final prefs = await SharedPreferences.getInstance();
    if (!stillPresent && previouslySelectedId != null) {
      await prefs.setString('active_scope', 'portfolio');
      await prefs.remove('active_property_id');
    }
    final selected = _selectedContextOrFallback();
    final choice = await showModalBottomSheet<_PropertyContextOption>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0x22000000),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose property context',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ..._propertyContexts.map((ctx) {
                  final isSelected =
                      ctx.id == selected.id && ctx.scope == selected.scope;
                  final icon = ctx.scope == 'portfolio'
                      ? Icons.dashboard_rounded
                      : Icons.apartment_rounded;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => Navigator.of(context).pop(ctx),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFF2FAF9)
                            : const Color(0xFFF9FBFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0x5500C6A6)
                              : const Color(0x2200C6A6),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            size: 18,
                            color: const Color(0xFF167D60),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ctx.label,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF167D60),
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (choice != null) {
      await _onContextChanged(choice);
    }
  }

  Future<void> _openRazorpayPayment({
    required String orderId,
    required int amount,
  }) async {
    try {
      // Ensure Razorpay is initialized
      if (_razorpay == null) {
        debugPrint('Razorpay not initialized, initializing now...');
        _razorpay = Razorpay()
          ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess)
          ..on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError)
          ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handlePaymentExternal);
      }

      final options = {
        'key': 'rzp_test_v4oAPsjPGsrOQR', // TODO: replace with live key in prod
        'amount': amount,
        'currency': 'INR',
        'order_id': orderId,
        'method': {
          'upi': true,
          'netbanking': true,
          'paylater': false,
          'card': true
        },
        'theme': {'color': '#3399cc'},
      };

      _razorpay!.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open payment gateway')),
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    // If there's a file selected, upload it with the query
    if (_selectedFilePath != null) {
      final query = text.isEmpty
          ? "Please extract and summarize the lease details"
          : text;
      await _uploadFileWithQuery(_selectedFilePath!, _selectedFileName!, query);
      // Clear file selection after sending
      setState(() {
        _selectedFilePath = null;
        _selectedFileName = null;
      });
      _messageController.clear();
      return;
    }

    // Otherwise, send normal text message
    if (text.isEmpty || _isSendingMessage) return;

    setState(() {
      messages
          .add({"sender": "user", "text": text, "timestamp": DateTime.now()});
      _messageController.clear();
      _isSendingMessage = true;
    });

    // Scroll to bottom
    _scrollToBottom();

    try {
      final propertyContext = await _buildPropertyContextForChat();

      // Build conversation history from messages (exclude the current message we're about to send)
      final conversationHistory = messages.map((msg) {
        return {
          "role": msg["sender"] == "user" ? "user" : "assistant",
          "content": msg["text"]
        };
      }).toList();

      final body = <String, dynamic>{
        "message": text,
        "session_id": _sessionId,
        "conversation_history": conversationHistory,
        "user_role": _userRole,
        "active_scope": _activeScope,
        "property_context": propertyContext,
      };
      if (_userRole == 'landlord') {
        body['landlord_lease_count'] = _landlordLeaseCount;
      }
      if (_activeScope == 'property' && _activePropertyId != null) {
        // Context selector id is the lease_id (one entry per lease)
        body["lease_id"] = int.tryParse(_activePropertyId!);
        body["property_id"] = int.tryParse(_activePropertyId!);
      }

      final prefs = await SharedPreferences.getInstance();
      final sessionToken = prefs.getString('session_id');
      final headers = <String, String>{"Content-Type": "application/json"};
      if (sessionToken != null && sessionToken.trim().isNotEmpty) {
        headers["Authorization"] = "Bearer $sessionToken";
      }
      final response = await http.post(
        Uri.parse(ApiConfig.chatbotEndpoint),
        headers: headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final data = _decodeJsonMap(response);
        final aiText =
            data["response"] ?? "I'm sorry, I couldn't process that request.";

        setState(() {
          final msg = <String, dynamic>{
            "sender": "ai",
            "text": _sanitizeAiText(aiText.toString()),
            "timestamp": DateTime.now(),
          };
          if (data["chart"] is Map) {
            msg["chart"] = data["chart"];
          }
          messages.add(msg);
        });

        // Check if payment order was created and open Razorpay widget
        final paymentOrderId = data["payment_order_id"];
        final paymentAmount = data["payment_amount"];

        debugPrint(
            'Payment check - order_id: $paymentOrderId, amount: $paymentAmount');
        debugPrint('Full response data: $data');

        if (paymentOrderId != null && paymentAmount != null) {
          debugPrint(
              'Opening Razorpay with order_id: $paymentOrderId, amount: $paymentAmount');
          // Small delay to ensure UI is updated before opening payment widget
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _openRazorpayPayment(
                orderId: paymentOrderId.toString(),
                amount: paymentAmount is int
                    ? paymentAmount
                    : int.parse(paymentAmount.toString()),
              );
            }
          });
        } else {
          debugPrint(
              'No payment order detected. payment_order_id: $paymentOrderId, payment_amount: $paymentAmount');
        }

        // Chat-driven UI: open lease agreement wizard when backend signals
        final clientAction = data['action'] ?? data['client_action'];
        if (clientAction is String && clientAction.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 400), () {
            if (!mounted) return;
            if (clientAction == 'open_lease_agreement_widget') {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LeaseAgreementWizardPage(),
                ),
              );
            } else if (clientAction == 'open_lease_agreement_preview') {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const LeaseAgreementWizardPage(startOnPreview: true),
                ),
              );
            } else if (clientAction == 'open_docuseal_signing') {
              final payload = (data['action_payload'] ?? data['client_action_payload']);
              if (payload is Map<String, dynamic>) {
                final url = _pickDocusealLandlordUrl(payload);
                if (url != null && url.isNotEmpty) {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DocusealSigningWebViewPage(
                        signingUrl: url,
                        title: 'Sign as landlord',
                      ),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('DocuSeal signing URL missing in response.'),
                    ),
                  );
                }
              }
            }
          });
        }
      } else {
        setState(() {
          messages.add({
            "sender": "ai",
            "text":
                "⚠️ Server error: ${response.statusCode}. Please try again.",
            "timestamp": DateTime.now()
          });
        });
      }
    } catch (e) {
      setState(() {
        messages.add({
          "sender": "ai",
          "text":
              "❌ Could not connect to server. Please check your connection.",
          "timestamp": DateTime.now()
        });
      });
    } finally {
      setState(() {
        _isSendingMessage = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendQuickMessage(String message) {
    _messageController.text = message;
    _sendMessage();
  }

  void _startTenantOnboardingFlow() {
    final selectedLeaseId = _activeScope == 'property' ? _activePropertyId : null;
    if (selectedLeaseId != null && selectedLeaseId.trim().isNotEmpty) {
      _sendQuickMessage(
        'Onboard tenant for the currently selected property/lease. '
        'First confirm this is the correct lease, then collect/confirm tenant email and initiate DocuSeal signing.',
      );
      return;
    }
    _sendQuickMessage(
      'I want to onboard a tenant. First ask me which property/lease to use, '
      'then proceed with tenant email and DocuSeal signing.',
    );
  }

  Future<void> _openUpcomingDuesSheet() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionToken = prefs.getString('session_id');
    if (sessionToken == null || sessionToken.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sign in to see upcoming rent dues'),
          backgroundColor: Color(0xFF167D60),
        ),
      );
      return;
    }
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _UpcomingDuesSheet(sessionToken: sessionToken),
    );
  }

  Future<void> _pickAndUploadFile() async {
    if (_isUploadingFile || _isSendingMessage) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      final path = picked.path;
      if (path == null) {
        setState(() {
          messages.add({
            "sender": "ai",
            "text": "❌ Could not read file path.",
            "timestamp": DateTime.now()
          });
        });
        return;
      }

      // Store the file - don't upload yet, wait for user to send
      setState(() {
        _selectedFilePath = path;
        _selectedFileName = picked.name;
      });
      // No chat bubble here — composer already shows the attachment; one bubble on send only.
      _scrollToBottom();
    } catch (e) {
      setState(() {
        messages.add({
          "sender": "ai",
          "text": "❌ File selection failed: $e",
          "timestamp": DateTime.now()
        });
      });
    }
  }

  Future<void> _uploadFileWithQuery(
      String filePath, String filename, String query) async {
    setState(() {
      _isUploadingFile = true;
      _isSendingMessage = true;
      messages.add({
        "sender": "user",
        "type": "pdf_attachment",
        "fileName": filename,
        "timestamp": DateTime.now(),
      });
      _messageController.clear();
    });

    _scrollToBottom();

    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionId = prefs.getString('session_id');
      final uri = Uri.parse(ApiConfig.extractLeaseContentEndpoint);
      final req = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: filename,
          contentType: MediaType('application', 'pdf'),
        ))
        ..fields['query'] = query; // Add query as form field
      if (sessionId != null && sessionId.trim().isNotEmpty) {
        req.headers['Authorization'] = 'Bearer $sessionId';
      }

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final decoded = utf8.decode(res.bodyBytes);
        final Map<String, dynamic> payload = decoded.isEmpty
            ? {}
            : (jsonDecode(decoded) as Map<String, dynamic>);
        final Map<String, dynamic> fields =
            (payload['fields'] as Map?)?.cast<String, dynamic>() ?? {};

        // Use the agent's response if available, otherwise fall back to formatted fields
        String leaseDetails;
        if (payload['agent_response'] != null) {
          leaseDetails = payload['agent_response'] as String;
        } else {
          leaseDetails = "📄 Lease document processed successfully!\n\n";
          leaseDetails +=
              "**Property Address:** ${fields['property_address'] ?? 'N/A'}\n";
          leaseDetails +=
              "**Rent Amount:** ₹${fields['rent_amount_inr'] ?? 'N/A'}\n";
          leaseDetails += "**Start Date:** ${fields['start_date'] ?? 'N/A'}\n";
          leaseDetails += "**End Date:** ${fields['end_date'] ?? 'N/A'}\n";
          leaseDetails += "**Landlord:** ${fields['landlord_name'] ?? 'N/A'}\n";
          leaseDetails += "**Tenant:** ${fields['tenant_name'] ?? 'N/A'}\n\n";
          leaseDetails += "You can now ask me questions about this lease!";
        }

        setState(() {
          messages.add({
            "sender": "ai",
            "text": _sanitizeAiText(leaseDetails),
            "timestamp": DateTime.now()
          });
        });

        // Save to local store only when it's a new lease (not a duplicate)
        final isDuplicate = payload['duplicate'] == true;
        if (!isDuplicate) {
          try {
            final leaseData = LeaseData.fromExtractedFields(fields);
            await LeaseStore().addLease(leaseData);
          } catch (e) {
            print('Error saving lease to store: $e');
          }
        }
      } else {
        setState(() {
          messages.add({
            "sender": "ai",
            "text": "⚠️ Server error ${res.statusCode}: ${res.body}",
            "timestamp": DateTime.now()
          });
        });
      }
    } catch (e) {
      setState(() {
        messages.add({
          "sender": "ai",
          "text": "❌ File upload error: $e",
          "timestamp": DateTime.now()
        });
      });
    } finally {
      setState(() {
        _isUploadingFile = false;
        _isSendingMessage = false;
      });
      _scrollToBottom();
    }
  }

  /// Backend sometimes returns placeholder first names (e.g. "Test"); prefer real prefs.
  static bool _looksLikePlaceholderDisplayName(String s) {
    final t = s.trim().toLowerCase();
    if (t.isEmpty) return true;
    const placeholders = {'test', 'user', 'demo', 'placeholder'};
    return placeholders.contains(t);
  }

  static String _resolveDisplayFirstName(
    String apiFirst,
    String apiFull,
    String fallback,
  ) {
    if (!_looksLikePlaceholderDisplayName(apiFirst)) return apiFirst.trim();
    if (apiFull.isNotEmpty) {
      final parts =
          apiFull.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
      if (parts.isNotEmpty) {
        final first = parts.first;
        if (!_looksLikePlaceholderDisplayName(first)) return first;
      }
    }
    return fallback;
  }

  Future<void> fetchUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Login stores `session_id`; keep `session_token` fallback for older installs.
      final sessionToken =
          prefs.getString('session_id') ?? prefs.getString('session_token');
      final onboardingFirstName = prefs.getString('onboarding_first_name');
      final savedDisplayName = prefs.getString('user_name');
      var fallbackName = (onboardingFirstName != null &&
              onboardingFirstName.trim().isNotEmpty)
          ? onboardingFirstName.trim()
          : ((savedDisplayName != null && savedDisplayName.trim().isNotEmpty)
              ? savedDisplayName.trim().split(' ').first
              : "User");
      if (_looksLikePlaceholderDisplayName(fallbackName)) {
        fallbackName = 'User';
      }

      // Show local profile name immediately; backend can overwrite with fresher value.
      setState(() {
        userName = fallbackName;
      });

      if (sessionToken == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse(ApiConfig.userProfileEndpoint),
        headers: {
          "Authorization": "Bearer $sessionToken",
        },
      );

      if (response.statusCode == 200) {
        final data = _decodeJsonMap(response);
        final apiFirstName = (data["first_name"] ?? "").toString().trim();
        final apiName = (data["name"] ?? "").toString().trim();
        final resolvedName = _resolveDisplayFirstName(
          apiFirstName,
          apiName,
          fallbackName,
        );

        setState(() {
          userName = resolvedName;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  String getGreetingMessage() {
    // Get current time in EST/EDT (UTC-5 or UTC-4)
    final now = DateTime.now().toUtc();
    // EST is UTC-5, EDT is UTC-4 (rough approximation)
    // For simplicity, we'll use UTC-5 (EST) or check if DST is active
    final isDST = _isDaylightSavingTime(now);
    final estOffset = isDST ? -4 : -5;
    final estTime = now.add(Duration(hours: estOffset));

    final hour = estTime.hour;
    final name = userName ?? "User";

    if (hour < 12) return "Good morning, $name";
    if (hour < 17) return "Good afternoon, $name";
    return "Good evening, $name";
  }

  bool _isDaylightSavingTime(DateTime utcTime) {
    // DST in US Eastern Time typically runs from second Sunday in March to first Sunday in November
    final month = utcTime.month;
    if (month < 3 || month > 11) return false;
    if (month > 3 && month < 11) return true;
    // For March and November, need to check specific dates
    // Simplified: assume DST from March to November
    return month >= 3 && month <= 11;
  }

  Widget _buildInitialState() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 80),
            // Greeting
            Text(
              getGreetingMessage(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 48),
            // Action buttons - 2x2 grid
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.home_outlined,
                    label: 'View Portfolio',
                    onTap: () => _sendQuickMessage('View Portfolio'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.description_outlined,
                    label: 'Review lease',
                    onTap: () => _sendQuickMessage('Review lease'),
                  ),
                ),
              ],
            ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.person_add_alt_1_outlined,
                        label: 'Onboard Tenant',
                        onTap: _startTenantOnboardingFlow,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.notifications_outlined,
                        label: 'Reminders',
                        onTap: _openUpcomingDuesSheet,
                      ),
                    ),
                  ],
                ),
            const SizedBox(height: 60),
            // Bottom text
            const Text(
              'Your rent, collected and tracked on time.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: Color(0xFF9B9B9B),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// User bubble: PDF upload uses [type] + [fileName]; legacy messages used "📄 name".
  String? _userPdfAttachmentName(Map<String, dynamic> msg) {
    if (msg['type'] == 'pdf_attachment') {
      final fn = msg['fileName'];
      if (fn is String && fn.trim().isNotEmpty) return fn.trim();
    }
    final text = msg['text']?.toString() ?? '';
    if (text.startsWith('📄 ')) return text.substring(2).trim();
    return null;
  }

  Widget _buildChatView() {
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isUser = message["sender"] == "user";
        final pdfAttachName = isUser ? _userPdfAttachmentName(message) : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                // AI: Glowing teal glassmorphism icon
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFCBF8F3),
                        Color(0xFF9EE8DD),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFCBF8F3).withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // AI: Rendered markdown + optional insight chart
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FCFB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFE0F2EF),
                            width: 1,
                          ),
                        ),
                        child: MarkdownBody(
                          data: _sanitizeAiText(message["text"]?.toString() ?? ''),
                          shrinkWrap: true,
                          onTapLink: (text, href, title) {
                            // No-op: avoid broken / non-launchable assistant URLs in WebView.
                          },
                          styleSheet: MarkdownStyleSheet(
                            p: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF1A1A1A),
                              height: 1.45,
                            ),
                            a: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF1A1A1A),
                              height: 1.45,
                              decoration: TextDecoration.none,
                            ),
                            strong: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0D1F1A),
                            ),
                            listBullet: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF1AAE9F),
                              height: 1.45,
                            ),
                            listIndent: 20,
                            blockSpacing: 8,
                            blockquote: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF4D5F73),
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
                            blockquoteDecoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: const Color(0xFF1AAE9F),
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (message["chart"] is Map) ...[
                        const SizedBox(height: 12),
                        _InsightChart(data: message["chart"] as Map<String, dynamic>),
                      ],
                    ],
                  ),
                ),
              ],
              if (isUser) ...[
                Flexible(
                  child: pdfAttachName != null
                      ? _PdfAttachmentChip(fileName: pdfAttachName)
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            message["text"]?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF1A1A1A),
                              height: 1.4,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                // User: Teal circular avatar with white person outline
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBF8F3), // Teal color
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openAddPaymentSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddPaymentModal(),
    );
  }

  /// Bottom nav **Home** — back to greeting + quick actions (clears in-memory chat only).
  void _resetToHomeDashboard() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      messages.clear();
      _messageController.clear();
      _selectedFilePath = null;
      _selectedFileName = null;
      _isSendingMessage = false;
      _isUploadingFile = false;
      _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_token');
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final selectedContext =
        _userRole == 'landlord' ? _selectedContextOrFallback() : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        onPanDown: (_) => FocusManager.instance.primaryFocus?.unfocus(),
        child: SafeArea(
          child: Column(
            children: [
            // Logo at top
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/logo.png',
                        height: 48,
                        width: 48,
                        cacheWidth: 144,
                        cacheHeight: 144,
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2FAF9),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0x2200C6A6)),
                        ),
                        child: Text(
                          _userRole == 'landlord' ? 'Landlord' : 'Tenant',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF167D60),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_userRole == 'landlord') ...[
                    const SizedBox(height: 10),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _showContextPickerSheet,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FCFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x2200C6A6)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedContext?.scope == 'portfolio'
                                  ? Icons.dashboard_rounded
                                  : Icons.apartment_rounded,
                              size: 18,
                              color: const Color(0xFF167D60),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedContext?.label ??
                                    'Portfolio (All Properties)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.unfold_more_rounded,
                              color: Color(0xFF6B6B6B),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _activeContextLabel(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_userRole == 'landlord' &&
                _landlordLeaseCount == 0 &&
                !_landlordEmptyPortfolioBannerDismissed)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Material(
                  color: const Color(0xFFF2FAF9),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 20,
                          color: Color(0xFF167D60),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Start here: open Settings → Properties to add your first property or lease. You can also attach a PDF with the clip icon or type “create a lease”.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          color: const Color(0xFF6B6B6B),
                          onPressed: _dismissLandlordEmptyPortfolioBanner,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Chat interface
            Expanded(
              child: messages.isEmpty ? _buildInitialState() : _buildChatView(),
            ),
            // Typing indicator (dots above input bar, OpenAI-style)
            if (_isSendingMessage || _isUploadingFile) _TypingDots(),
            // Input field with send button - white glassy (matches agent bubble)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: _selectedFileName != null
                      ? const Color(0xFFF0FAF9)
                      : const Color(0xFFF7FCFB),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _selectedFileName != null
                        ? const Color(0xFFB8E6E1)
                        : const Color(0xFFE0F2EF),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Lease / attach icon - no spinner when loading; dots show above
                    GestureDetector(
                      onTap: _isUploadingFile ? null : _pickAndUploadFile,
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(left: 6, top: 6, bottom: 6),
                        decoration: BoxDecoration(
                          color: _selectedFileName != null
                              ? const Color(0xFFE0F5F3)
                              : const Color(0xFFF5F5F5),
                          shape: BoxShape.circle,
                          border: _selectedFileName != null
                              ? Border.all(
                                  color: const Color(0xFF1AAE9F).withOpacity(0.4),
                                  width: 1.2,
                                )
                              : null,
                        ),
                        child: Icon(
                          _selectedFileName != null
                              ? Icons.description_rounded
                              : Icons.attach_file_rounded,
                          color: (_isUploadingFile || _selectedFileName != null)
                              ? const Color(0xFF1AAE9F)
                              : const Color(0xFF5C5C5C),
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: _selectedFileName != null
                              ? 'Ask about this lease...'
                              : _userRole == 'landlord'
                                  ? 'e.g. create a lease, my leases, rent reminder…'
                                  : 'How may I assist you?',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9B9B9B),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.only(
                            left: 8,
                            right: 8,
                            top: 16,
                            bottom: 16,
                          ),
                          suffixIcon: _selectedFileName != null
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedFilePath = null;
                                        _selectedFileName = null;
                                      });
                                    },
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFFE0E0E0),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.06),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: Color(0xFF6B6B6B),
                                      ),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF1A1A1A),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                    // Send button - no spinner; dots above show loading
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
                        decoration: BoxDecoration(
                          gradient: (_isSendingMessage || _isUploadingFile)
                              ? null
                              : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF1AAE9F),
                                    Color(0xFF158F7A),
                                  ],
                                ),
                          color: (_isSendingMessage || _isUploadingFile)
                              ? const Color(0xFFE0E0E0)
                              : null,
                          shape: BoxShape.circle,
                          boxShadow: (_isSendingMessage || _isUploadingFile)
                              ? null
                              : [
                                  BoxShadow(
                                    color: const Color(0xFF1AAE9F).withOpacity(0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
        onTap: (index) async {
          switch (index) {
            case 0:
              _resetToHomeDashboard();
              break;
            // case 1: Payments – commented out
            // _openAddPaymentSheet();
            // break;
            case 1:
              Navigator.pushNamed(context, '/settings');
              break;
            case 2:
              await _signOut();
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          // BottomNavigationBarItem(
          //     icon: Icon(Icons.payments), label: 'Payments'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
          BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Sign Out'),
        ],
      ),
    );
  }
}

/// Styled chip for a sent PDF (matches app teal + clear PDF affordance).
class _PdfAttachmentChip extends StatelessWidget {
  final String fileName;

  const _PdfAttachmentChip({required this.fileName});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF7FCFB),
            Color(0xFFEEF6FC),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF1A6FD4).withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A6FD4).withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF42A5F5),
                  Color(0xFF1565C0),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.28),
                  blurRadius: 5,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'PDF',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.35,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Action button widget for the chat interface
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Icon(
              icon,
              size: 18,
              color: const Color(0xFF1A1A1A),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet showing top 3 upcoming rent dues from the API.
class _UpcomingDuesSheet extends StatefulWidget {
  final String sessionToken;

  const _UpcomingDuesSheet({required this.sessionToken});

  @override
  State<_UpcomingDuesSheet> createState() => _UpcomingDuesSheetState();
}

class _UpcomingDuesSheetState extends State<_UpcomingDuesSheet> {
  List<Map<String, dynamic>> _dues = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUpcomingDues();
  }

  Future<void> _fetchUpcomingDues() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse('${ApiConfig.upcomingDuesEndpoint}?limit=3');
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.sessionToken}'},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final list = decoded is List ? decoded : (decoded is Map && decoded['items'] is List ? decoded['items'] as List : <dynamic>[]);
        setState(() {
          _dues = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading = false;
          _error = null;
        });
      } else {
        setState(() {
          _error = 'Could not load reminders (${response.statusCode})';
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Connection error. Please try again.';
        _loading = false;
      });
    }
  }

  String _formatDueDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      const months = 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec';
      final parts = months.split(' ');
      final month = d.month >= 1 && d.month <= 12 ? parts[d.month - 1] : '';
      return '${d.day} $month ${d.year}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      maxChildSize: 0.7,
      minChildSize: 0.3,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0x22000000),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Upcoming dues',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF1AAE9F)))
                    : _error != null
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 15),
                                ),
                                const SizedBox(height: 16),
                                TextButton.icon(
                                  onPressed: _fetchUpcomingDues,
                                  icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF1AAE9F)),
                                  label: const Text('Retry', style: TextStyle(color: Color(0xFF1AAE9F))),
                                ),
                              ],
                            ),
                          )
                        : _dues.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                  child: Text(
                                    'No upcoming dues right now.\nRent due dates will appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Color(0xFF6B6B6B), fontSize: 15),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                itemCount: _dues.length,
                                itemBuilder: (context, index) {
                                  final d = _dues[index];
                                  final propertyName = (d['property_name'] as String?)?.trim() ?? 'Property';
                                  final tenantName = (d['tenant_name'] as String?)?.trim() ?? '—';
                                  final dueDate = _formatDueDate(d['due_date'] as String?);
                                  final rent = d['monthly_rent'] is int
                                      ? d['monthly_rent'] as int
                                      : int.tryParse(d['monthly_rent']?.toString() ?? '0') ?? 0;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7FCFB),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: const Color(0xFFE0F2EF)),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0F2EF),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF1AAE9F), size: 20),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                propertyName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                  color: Color(0xFF1A1A1A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Due $dueDate · $tenantName',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF6B6B6B),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '₹${rent.toStringAsFixed(0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: Color(0xFF1AAE9F),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================
// Add Payment Bottom Sheet
// ==========================
class AddPaymentModal extends StatefulWidget {
  const AddPaymentModal({Key? key}) : super(key: key);

  @override
  State<AddPaymentModal> createState() => _AddPaymentModalState();
}

class _AddPaymentModalState extends State<AddPaymentModal> {
  final _amountController = TextEditingController();
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay()
      ..on(Razorpay.EVENT_PAYMENT_SUCCESS, _handleSuccess)
      ..on(Razorpay.EVENT_PAYMENT_ERROR, _handleError)
      ..on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternal);
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  Future<bool> _verifyPaymentOnServer(PaymentSuccessResponse response) async {
    final orderId = response.orderId;
    final paymentId = response.paymentId;
    final signature = response.signature;
    if (orderId == null || paymentId == null || signature == null) {
      return false;
    }

    try {
      final verifyRes = await http.post(
        Uri.parse(ApiConfig.verifyPaymentEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'order_id': orderId,
          'payment_id': paymentId,
          'signature': signature,
        }),
      );
      if (verifyRes.statusCode != 200) return false;
      final payload = jsonDecode(utf8.decode(verifyRes.bodyBytes));
      return payload is Map<String, dynamic> && payload['success'] == true;
    } catch (_) {
      return false;
    }
  }

  void _handleSuccess(PaymentSuccessResponse response) async {
    final verified = await _verifyPaymentOnServer(response);
    if (!mounted) return;
    if (verified) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment successful!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment verification failed.')),
      );
    }
  }

  void _handleError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment failed: ${response.message}')),
    );
  }

  void _handleExternal(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet: ${response.walletName}')),
    );
  }

  Future<void> _openRazorpayPayment({
    required String orderId,
    required int amount,
  }) async {
    try {
      final options = {
        'key': 'rzp_test_v4oAPsjPGsrOQR', // TODO: replace with live key in prod
        'amount': amount,
        'currency': 'INR',
        'order_id': orderId,
        'method': {
          'upi': true,
          'netbanking': true,
          'paylater': false,
          'card': true
        },
        'theme': {'color': '#3399cc'},
      };

      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to open payment gateway')),
      );
    }
  }

  Future<void> _submitPayment() async {
    FocusScope.of(context).unfocus(); // hide keyboard first
    final raw = _amountController.text.trim();
    if (raw.isEmpty) return;

    try {
      final amount = int.parse(raw) * 100; // INR → paise

      final response = await http.post(
        Uri.parse(ApiConfig.createPaymentOrderEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'receipt_id': 'rcptid_${DateTime.now().millisecondsSinceEpoch}',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to create payment order');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));

      await _openRazorpayPayment(
        orderId: data['id'],
        amount: amount,
      );
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final buttonText = _amountController.text.isEmpty
        ? 'Pay securely'
        : 'Pay ₹${_amountController.text}';

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.95,
      minChildSize: 0.32,
      expand: false,
      builder: (context, scrollController) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return AnimatedPadding(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                controller: scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Grab handle
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0x22000000),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Text(
                      'Make a payment',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text('Powered by Razorpay',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 24),

                    TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submitPayment(),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Enter amount',
                        prefixText: '₹ ',
                        prefixStyle: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF4F5F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 16),
                      ),
                    ),

                    const SizedBox(height: 24),

                    ElevatedButton.icon(
                      icon: Image.asset('assets/razorpay.png',
                          height: 50, fit: BoxFit.contain),
                      onPressed: _submitPayment,
                      label: Text(buttonText),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C4FF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(
                      'UPI, cards, and wallets via Razorpay Checkout.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _formatInsightAmount(double v) {
  if (v == v.roundToDouble()) {
    return NumberFormat.currency(
      locale: 'en_US',
      symbol: r'$',
      decimalDigits: 0,
    ).format(v);
  }
  return NumberFormat.currency(
    locale: 'en_US',
    symbol: r'$',
    decimalDigits: 2,
  ).format(v);
}

/// Renders a small line or bar chart for insight (text2sql) results.
class _InsightChart extends StatelessWidget {
  final Map<String, dynamic> data;

  const _InsightChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final labels = data["labels"] as List<dynamic>? ?? [];
    final values = data["values"] as List<dynamic>? ?? [];
    final chartType = (data["chartType"] as String?)?.toLowerCase() ?? "line";
    final title = data["title"] as String?;

    if (labels.isEmpty || values.isEmpty) return const SizedBox.shrink();

    final labelStrings = labels.map((e) => e.toString()).toList();
    final valueNumbers = values.map((e) {
      if (e is num) return e.toDouble();
      return double.tryParse(e.toString()) ?? 0.0;
    }).toList();
    final maxY = valueNumbers.isEmpty ? 1.0 : (valueNumbers.reduce((a, b) => a > b ? a : b) * 1.1).clamp(1.0, double.infinity);
    final yTickInterval = maxY <= 0 ? 1.0 : (maxY / 4).clamp(1.0, double.infinity);
    const barGradient = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [
        Color(0xFFC8EFE8),
        Color(0xFF8FD9CC),
      ],
    );
    const teal = Color(0xFF1AAE9F);

    Widget chart;
    if (chartType == "bar" && labelStrings.length <= 12) {
      final barGroups = List.generate(
        valueNumbers.length,
        (i) => BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: valueNumbers[i],
              gradient: barGradient,
              width: 22,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        ),
      );
      chart = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.center,
                groupsSpace: 28,
                minY: 0,
                maxY: maxY,
                barGroups: barGroups,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    tooltipRoundedRadius: 10,
                    tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    tooltipMargin: 8,
                    maxContentWidth: 160,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    tooltipHorizontalAlignment: FLHorizontalAlignment.center,
                    tooltipBorder: const BorderSide(
                      color: Color(0xFFB8E0D8),
                      width: 1,
                    ),
                    getTooltipColor: (_) => const Color(0xFFEAF8F5),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final idx = group.x.toInt();
                      if (idx < 0 || idx >= valueNumbers.length) {
                        return null;
                      }
                      return BarTooltipItem(
                        _formatInsightAmount(valueNumbers[idx]),
                        const TextStyle(
                          color: Color(0xFF1F6F62),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i >= 0 && i < labelStrings.length) {
                          final s = labelStrings[i];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              s.length > 10 ? "${s.substring(0, 9)}…" : s,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF5C7A75),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                      reservedSize: 30,
                      interval: 1,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: yTickInterval,
                      getTitlesWidget: (value, meta) {
                        if (value < 0 || value > maxY * 1.02) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          value >= 1000
                              ? "${(value / 1000).round()}k"
                              : value.round().toString(),
                          style: const TextStyle(
                            color: Color(0xFF7A908C),
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yTickInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: const Color(0xFFE3F0ED),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(
              labelStrings.length,
              (i) => Expanded(
                child: Text(
                  _formatInsightAmount(valueNumbers[i]),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D8A7A),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      final spots = List.generate(
        valueNumbers.length,
        (i) => FlSpot(i.toDouble(), valueNumbers[i]),
      );
      chart = SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: teal,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: teal.withOpacity(0.15),
                ),
              ),
            ],
            minX: 0,
            maxX: (valueNumbers.length - 1).toDouble(),
            minY: 0,
            maxY: maxY,
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final i = value.round();
                    if (i >= 0 && i < labelStrings.length) {
                      final s = labelStrings[i];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          s.length > 8 ? "${s.substring(0, 7)}…" : s,
                          style: const TextStyle(
                            color: Color(0xFF6B6B6B),
                            fontSize: 10,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  reservedSize: 28,
                  interval: 1,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (value, meta) => Text(
                    value >= 1000 ? "${(value / 1000).toStringAsFixed(0)}k" : value.toStringAsFixed(0),
                    style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 10),
                  ),
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FCFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0F2EF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null && title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
                maxLines: 4,
                softWrap: true,
              ),
            ),
          chart,
        ],
      ),
    );
  }
}

/// OpenAI-style typing indicator: three pulsing dots above the input bar.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = (_controller.value + i * 0.33) % 1.0;
              final opacity =
                  0.3 + 0.7 * (1 - (t - 0.5).abs() * 2).clamp(0.0, 1.0);
              return Container(
                margin: const EdgeInsets.only(right: 4),
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1AAE9F).withOpacity(opacity),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
