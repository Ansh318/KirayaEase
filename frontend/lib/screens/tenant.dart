// tenant_dashboard_v2.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import '../services/lease_store.dart';
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

class _TenantDashboardV2State extends State<TenantDashboardV2> {
  final Color bgColor = const Color(0xFFCBF8F3);
  String? userName;
  String _userRole = 'tenant';
  String _activeScope = 'self'; // self | portfolio | property
  String? _activePropertyId;
  List<_PropertyContextOption> _propertyContexts = const [];
  bool isLoading = true;

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
    return text
        .replaceAll('â¹', '₹')
        .replaceAll('Â₹', '₹')
        .replaceAll('â', '-')
        .replaceAll('â', "'")
        .replaceAll('â', '"')
        .replaceAll('â', '"');
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
  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

    List<_PropertyContextOption> contexts = const [];
    if (role == 'landlord') {
      contexts = await _buildLandlordPropertyContexts();
    }

    if (!mounted) return;
    setState(() {
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
  }

  Future<List<_PropertyContextOption>> _buildLandlordPropertyContexts() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString('session_id');
    if (sessionId == null || sessionId.trim().isEmpty) {
      return [
        const _PropertyContextOption(
          id: 'portfolio',
          label: 'Portfolio (All Properties)',
          scope: 'portfolio',
        ),
      ];
    }
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.propertiesEndpoint),
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
        final id = map['id'];
        final name = map['name']?.toString().trim() ?? 'Property ${contexts.length}';
        if (id == null) continue;
        contexts.add(
          _PropertyContextOption(
            id: id.toString(),
            label: name,
            scope: 'property',
            propertyData: map,
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
      if (_activeScope == 'property' && _activePropertyId != null) {
        body["property_id"] = int.tryParse(_activePropertyId!) ?? 0;
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
          messages.add({
            "sender": "ai",
            "text": _sanitizeAiText(aiText.toString()),
            "timestamp": DateTime.now()
          });
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

      // Show file selected message
      setState(() {
        messages.add({
          "sender": "user",
          "text": picked.name,
          "timestamp": DateTime.now()
        });
      });
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
      // Show user's message with file
      if (query.isNotEmpty) {
        messages.add({
          "sender": "user",
          "text": "📄 $filename\n\n$query",
          "timestamp": DateTime.now()
        });
      } else {
        messages.add({
          "sender": "user",
          "text": "📄 $filename",
          "timestamp": DateTime.now()
        });
      }
      _messageController.clear();
    });

    _scrollToBottom();

    try {
      final uri = Uri.parse(ApiConfig.extractLeaseContentEndpoint);
      final req = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: filename,
          contentType: MediaType('application', 'pdf'),
        ))
        ..fields['query'] = query; // Add query as form field

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
          // Use the intelligent agent response
          leaseDetails = payload['agent_response'] as String;
        } else {
          // Fallback: Format the extracted lease details as a message
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

        // Save extracted lease data to store
        try {
          final leaseData = LeaseData.fromExtractedFields(fields);
          await LeaseStore().addLease(leaseData);
        } catch (e) {
          print('Error saving lease to store: $e');
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

  Future<void> fetchUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionToken = prefs.getString('session_token');
      final onboardingFirstName = prefs.getString('onboarding_first_name');
      final savedDisplayName = prefs.getString('user_name');
      final fallbackName = (onboardingFirstName != null &&
              onboardingFirstName.trim().isNotEmpty)
          ? onboardingFirstName.trim()
          : ((savedDisplayName != null && savedDisplayName.trim().isNotEmpty)
              ? savedDisplayName.trim().split(' ').first
              : "User");

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
        final resolvedName = apiFirstName.isNotEmpty
            ? apiFirstName
            : (apiName.isNotEmpty ? apiName.split(' ').first : fallbackName);

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
            const SizedBox(height: 12),
            // Subtitle
            const Text(
              'Your AI-powered rental assistant',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: Color(0xFF6B6B6B),
              ),
            ),
            const SizedBox(height: 60),
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
                    icon: Icons.calendar_today_outlined,
                    label: 'Insights Report',
                    onTap: () => _sendQuickMessage('Insights Report'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.trending_up_outlined,
                    label: 'Market trends',
                    onTap: () => _sendQuickMessage('Market trends'),
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

  Widget _buildChatView() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: messages.length + (_isSendingMessage ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == messages.length) {
          // Loading indicator with AI icon style
          return Padding(
            padding: const EdgeInsets.only(left: 0, top: 8, bottom: 8),
            child: Row(
              children: [
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
                    child: const Padding(
                      padding: EdgeInsets.all(5.0),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          );
        }

        final message = messages[index];
        final isUser = message["sender"] == "user";

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
                // AI: Text without bubble, directly on background
                Flexible(
                  child: Text(
                    message["text"],
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1A1A1A),
                      height: 1.4,
                      // Don't specify fontFamily to use system default which supports emojis
                    ),
                  ),
                ),
              ],
              if (isUser) ...[
                // User: Light gray rounded bubble
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      message["text"],
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1A1A1A),
                        height: 1.4,
                        // Don't specify fontFamily to use system default which supports emojis
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
      body: SafeArea(
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
            // Chat interface
            Expanded(
              child: messages.isEmpty ? _buildInitialState() : _buildChatView(),
            ),
            // Input field with send button - always visible at bottom
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // File upload button
                    GestureDetector(
                      onTap: _isUploadingFile ? null : _pickAndUploadFile,
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(left: 8),
                        decoration: BoxDecoration(
                          color: _isUploadingFile
                              ? const Color(0xFFE0E0E0)
                              : const Color(0xFFF5F5F5),
                          shape: BoxShape.circle,
                        ),
                        child: _isUploadingFile
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF1A1A1A),
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.attach_file,
                                color: Color(0xFF1A1A1A),
                                size: 18,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: _selectedFileName != null
                              ? 'Type your question about ${_selectedFileName}...'
                              : 'How may I assist you?',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9B9B9B),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.only(
                            left: 12,
                            right: 12,
                            top: 16,
                            bottom: 16,
                          ),
                          suffixIcon: _selectedFileName != null
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _selectedFileName!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedFilePath = null;
                                            _selectedFileName = null;
                                          });
                                        },
                                        child: Icon(
                                          Icons.close,
                                          size: 16,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
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
                    // Send button inside input field
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: _isSendingMessage
                              ? const Color(0xFFE0E0E0)
                              : const Color(0xFFF5F5F5),
                          shape: BoxShape.circle,
                        ),
                        child: _isSendingMessage
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF1A1A1A),
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.arrow_upward,
                                color: Color(0xFF1A1A1A),
                                size: 18,
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
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey[600],
        type: BottomNavigationBarType.fixed,
        onTap: (index) async {
          switch (index) {
            case 0:
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
