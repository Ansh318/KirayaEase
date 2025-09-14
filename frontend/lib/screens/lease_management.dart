// // lease.dart
// // Full-screen page to view existing leases and upload a new lease PDF.
// // EXACTLY like your screenshot: Verified badge on the right,
// // and a status line *below it* — green dot + "Active" (black text) OR plain "Expired" (black text).
// // No global apiBase import; this page uses its own baseUrl.

// import 'dart:convert';
// import 'dart:io';
// import 'package:file_picker/file_picker.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;

// class LeasePage extends StatefulWidget {
//   /// e.g. 'https://kirayaease-2a527d924296.herokuapp.com'
//   final String baseUrl = 'https://kirayaease-2a527d924296.herokuapp.com';

//   const LeasePage({super.key});

//   @override
//   State<LeasePage> createState() => _LeasePageState();
// }

// class _LeasePageState extends State<LeasePage> {
//   bool _uploading = false;

//   final List<_Lease> _leases = <_Lease>[
//     _Lease(
//       title: 'Lakeside Villa',
//       rentDisplay: '₹1,80,000/yr',
//       start: DateTime(2023, 11, 1),
//       end: DateTime(2024, 10, 31),
//       verified: true,
//     ),
//     _Lease(
//       title: 'Maple Apartments',
//       rentDisplay: '₹1,20,000/yr',
//       start: DateTime(2023, 7, 15),
//       end: DateTime(2024, 7, 14),
//       verified: true,
//     ),
//   ];

//   // ===== Upload flow =====
//   Future<void> _pickAndUpload() async {
//     try {
//       final result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: const ['pdf'],
//         withData: true,
//       );
//       if (result == null || result.files.isEmpty) return;

//       final file = result.files.first;
//       final Uint8List? bytes = file.bytes;

//       Uint8List payload;
//       if (bytes != null) {
//         payload = bytes;
//       } else {
//         final path = file.path;
//         if (path == null) {
//           _snack('Could not read file bytes.');
//           return;
//         }
//         final f = File(path);
//         if (!await f.exists()) {
//           _snack('File not found.');
//           return;
//         }
//         payload = await f.readAsBytes();
//       }

//       await _uploadToExtractor(payload, file.name);
//     } catch (e) {
//       _snack('Upload failed: $e');
//     }
//   }

//   Future<void> _uploadToExtractor(Uint8List bytes, String filename) async {
//     setState(() => _uploading = true);
//     try {
//       final uri = Uri.parse(
//         '${widget.baseUrl.replaceAll(RegExp(r"/$"), "")}/extract-lease',
//       );

//       final res = await http.post(
//         uri,
//         headers: {
//           'Content-Type': 'application/pdf',
//           'X-File-Name': filename,
//         },
//         body: bytes,
//       );

//       if (!mounted) return;

//       if (res.statusCode >= 200 && res.statusCode < 300) {
//         final Map<String, dynamic> data = res.body.isEmpty
//             ? {}
//             : jsonDecode(res.body) as Map<String, dynamic>;

//         final lease = _Lease.fromExtractor(data) ??
//             _Lease(
//               title: filename.replaceAll('.pdf', ''),
//               rentDisplay: data['rent_display']?.toString() ?? '—',
//               start: _tryParseDate(data['start_date']),
//               end: _tryParseDate(data['end_date']),
//               verified: true,
//             );

//         setState(() => _leases.insert(0, lease));
//         _snack('Lease uploaded & verified.');
//       } else {
//         _snack('Server error ${res.statusCode}: ${res.body}');
//       }
//     } catch (e) {
//       _snack('Network error: $e');
//     } finally {
//       if (mounted) setState(() => _uploading = false);
//     }
//   }

//   void _snack(String msg) =>
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

//   // ===== UI =====
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF7F7F8),
//       appBar: AppBar(
//         backgroundColor: const Color(0xFFF7F7F8),
//         elevation: 0,
//         centerTitle: false,
//         titleSpacing: 16,
//         title: const Text(
//           'Leases',
//           style: TextStyle(
//             fontSize: 28,
//             fontWeight: FontWeight.w800,
//             color: Colors.black,
//             letterSpacing: -0.2,
//           ),
//         ),
//       ),
//       body: ListView.separated(
//         padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
//         itemCount: _leases.length,
//         separatorBuilder: (_, __) => const SizedBox(height: 12),
//         itemBuilder: (context, i) => _LeaseCard(lease: _leases[i]),
//       ),
//       bottomNavigationBar: SafeArea(
//         minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
//         child: SizedBox(
//           height: 52,
//           width: double.infinity,
//           child: OutlinedButton(
//             onPressed: _uploading ? null : _pickAndUpload,
//             style: OutlinedButton.styleFrom(
//               backgroundColor: Colors.white,
//               side: const BorderSide(color: Colors.black, width: 1.4),
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(14),
//               ),
//             ),
//             child: Text(
//               _uploading ? 'Uploading…' : 'Upload Lease',
//               style: const TextStyle(
//                 color: Colors.black,
//                 fontWeight: FontWeight.w700,
//                 fontSize: 16,
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }

// // ===== Widgets =====

// class _LeaseCard extends StatelessWidget {
//   final _Lease lease;
//   const _LeaseCard({required this.lease});

//   bool get isActive {
//     final now = DateTime.now();
//     if (lease.end == null) return false;
//     // Active if end date is today or in the future (matches screenshot feeling)
//     return !lease.end!.isBefore(DateTime(now.year, now.month, now.day));
//   }

//   @override
//   Widget build(BuildContext context) {
//     final dateStyle = TextStyle(
//       color: Colors.black.withOpacity(0.7),
//       fontSize: 13, // smaller rent & dates as in your mock
//       height: 1.25,
//     );

//     return Container(
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(18),
//         border: Border.all(color: const Color(0xFFE6E6E9)),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x08000000),
//             blurRadius: 14,
//             offset: Offset(0, 6),
//           ),
//         ],
//       ),
//       padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Left block: Title + dates
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Professional title weight & spacing (but still bold like shot)
//                 const SizedBox(height: 2),
//                 Text(
//                   lease.title,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: const TextStyle(
//                     fontSize: 18,
//                     fontWeight: FontWeight.w800,
//                     letterSpacing: -0.1,
//                     color: Colors.black,
//                   ),
//                 ),
//                 const SizedBox(height: 6),
//                 Text('Rent: ${lease.rentDisplay}', style: dateStyle),
//                 const SizedBox(height: 2),
//                 Text(
//                   '${_fmtDate(lease.start)} – ${_fmtDate(lease.end)}',
//                   style: dateStyle,
//                 ),
//               ],
//             ),
//           ),

//           // Right block: verified badge + status (below it)
//           const Column(
//             crossAxisAlignment: CrossAxisAlignment.end,
//             children: [
//               _VerifiedBadge(),
//               SizedBox(height: 10),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// EXACT status line per screenshot:
// /// - If active: small green dot + "Active" in black.
// /// - If expired: just "Expired" in black (no dot).

// /// Meta-style blue tick
// class _VerifiedBadge extends StatelessWidget {
//   const _VerifiedBadge();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: const Color(0xFFE8F1FF),
//         borderRadius: BorderRadius.circular(999),
//         border: Border.all(color: const Color(0xFF1877F2)),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Container(
//             width: 18,
//             height: 18,
//             decoration: const BoxDecoration(
//               shape: BoxShape.circle,
//               color: Color(0xFF1877F2), // Meta blue
//             ),
//             child: const Icon(Icons.check, size: 14, color: Colors.white),
//           ),
//           const SizedBox(width: 6),
//           const Text(
//             'Verified',
//             style: TextStyle(
//               color: Color(0xFF1877F2),
//               fontWeight: FontWeight.w700,
//               fontSize: 13,
//               letterSpacing: -0.1,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ===== Model & helpers =====

// class _Lease {
//   final String title;
//   final String rentDisplay;
//   final DateTime? start;
//   final DateTime? end;
//   final bool verified;

//   _Lease({
//     required this.title,
//     required this.rentDisplay,
//     required this.start,
//     required this.end,
//     required this.verified,
//   });

//   /// Map extractor fields to this model.
//   /// Expected keys: property_name/title, rent_display/monthly_rent/annual_rent,
//   /// start_date, end_date, verified
//   static _Lease? fromExtractor(Map<String, dynamic> m) {
//     if (m.isEmpty) return null;
//     return _Lease(
//       title: (m['property_name'] ?? m['title'] ?? '').toString().trim().isEmpty
//           ? 'Lease'
//           : (m['property_name'] ?? m['title']).toString(),
//       rentDisplay: m['rent_display']?.toString() ??
//           _formatINR(m['monthly_rent'] ?? m['annual_rent']),
//       start: _tryParseDate(m['start_date']),
//       end: _tryParseDate(m['end_date']),
//       verified: (m['verified'] is bool) ? (m['verified'] as bool) : true,
//     );
//   }
// }

// String _fmtDate(DateTime? d) {
//   if (d == null) return '—';
//   const months = [
//     'Jan',
//     'Feb',
//     'Mar',
//     'Apr',
//     'May',
//     'Jun',
//     'Jul',
//     'Aug',
//     'Sep',
//     'Oct',
//     'Nov',
//     'Dec'
//   ];
//   return '${months[d.month - 1]} ${d.day}, ${d.year}';
// }

// DateTime? _tryParseDate(dynamic v) {
//   if (v == null) return null;
//   if (v is DateTime) return v;
//   if (v is int) {
//     // support epoch ms/seconds
//     if (v > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(v);
//     return DateTime.fromMillisecondsSinceEpoch(v * 1000);
//   }
//   if (v is String) {
//     try {
//       return DateTime.parse(v);
//     } catch (_) {
//       return null;
//     }
//   }
//   return null;
// }

// String _formatINR(dynamic amount) {
//   if (amount == null) return '—';
//   try {
//     final num a = (amount is String) ? num.parse(amount) : amount as num;
//     return '₹${a.toStringAsFixed(0)}';
//   } catch (_) {
//     return '₹$amount';
//   }
// }

// lease.dart
// Full-screen page to view existing leases and upload a new lease PDF.
// EXACTLY like your screenshot: Verified badge on the right,
// and a status line *below it* — green dot + "Active" (black text) OR plain "Expired" (black text).
// No global apiBase import; this page uses its own baseUrl.

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class LeasePage extends StatefulWidget {
  /// e.g. 'https://kirayaease-2a527d924296.herokuapp.com'
  final String baseUrl = 'https://kirayaease-2a527d924296.herokuapp.com';

  const LeasePage({super.key});

  @override
  State<LeasePage> createState() => _LeasePageState();
}

class _LeasePageState extends State<LeasePage> {
  bool _uploading = false;

  final List<_Lease> _leases = <_Lease>[
    _Lease(
      title: 'Lakeside Villa',
      rentDisplay: '₹1,80,000/yr',
      start: DateTime(2023, 11, 1),
      end: DateTime(2024, 10, 31),
      verified: true,
    ),
    _Lease(
      title: 'Maple Apartments',
      rentDisplay: '₹1,20,000/yr',
      start: DateTime(2023, 7, 15),
      end: DateTime(2024, 7, 14),
      verified: true,
    ),
  ];

  // ===== Upload flow (file path + multipart/form-data to /extract-lease-content/) =====
  Future<void> _pickAndUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withReadStream: false, // we want a file path
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.first;
      final path = picked.path;
      if (path == null) {
        _snack('Could not read file path.');
        return;
      }
      await _uploadToExtractorFromPath(path, picked.name);
    } catch (e) {
      _snack('Upload failed: $e');
    }
  }

  Future<void> _uploadToExtractorFromPath(
      String filePath, String filename) async {
    setState(() => _uploading = true);
    try {
      final base = widget.baseUrl.replaceAll(RegExp(r'/+$'), '');
      final uri =
          Uri.parse('$base/extract-lease-content/'); // <-- backend endpoint

      final req = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: filename,
          contentType: MediaType('application', 'pdf'),
        ));

      final streamed = await req.send();
      final res = await http.Response.fromStream(streamed);

      if (!mounted) return;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final Map<String, dynamic> payload = res.body.isEmpty
            ? {}
            : (jsonDecode(res.body) as Map<String, dynamic>);
        final Map<String, dynamic> fields =
            (payload['fields'] as Map?)?.cast<String, dynamic>() ?? {};

        // Map backend fields -> UI model
        final lease = _Lease(
          title: (fields['property_address'] as String?)
                  ?.split('\n')
                  .first
                  .trim()
                  .takeIf((s) => s.isNotEmpty) ??
              filename.replaceAll('.pdf', ''),
          rentDisplay:
              _formatINR(fields['rent_amount_inr'] ?? fields['monthly_rent']),
          start: _tryParseDate(fields['start_date']),
          end: _tryParseDate(fields['end_date']),
          verified: true, // extracted = verified
        );

        setState(() => _leases.insert(0, lease));
        _snack('Lease uploaded & verified.');
      } else {
        _snack('Server error ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      _snack('Network error: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          height: 52,
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _uploading ? null : _pickAndUpload,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Colors.black, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _uploading ? 'Uploading…' : 'Upload Lease',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ===== Widgets =====

class _LeaseCard extends StatelessWidget {
  final _Lease lease;
  const _LeaseCard({required this.lease});

  bool get isActive {
    final now = DateTime.now();
    if (lease.end == null) return false;
    // Active if end date is today or in the future
    return !lease.end!.isBefore(DateTime(now.year, now.month, now.day));
  }

  @override
  Widget build(BuildContext context) {
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
      child: Row(
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
            width: 18,
            height: 18,
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
              fontSize: 13,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Model & helpers =====

class _Lease {
  final String title;
  final String rentDisplay;
  final DateTime? start;
  final DateTime? end;
  final bool verified;

  _Lease({
    required this.title,
    required this.rentDisplay,
    required this.start,
    required this.end,
    required this.verified,
  });

  /// Optional mapper if your API returns a different shape.
  static _Lease? fromExtractor(Map<String, dynamic> m) {
    if (m.isEmpty) return null;
    return _Lease(
      title: (m['property_name'] ?? m['title'] ?? '').toString().trim().isEmpty
          ? 'Lease'
          : (m['property_name'] ?? m['title']).toString(),
      rentDisplay: m['rent_display']?.toString() ??
          _formatINR(m['monthly_rent'] ?? m['annual_rent']),
      start: _tryParseDate(m['start_date']),
      end: _tryParseDate(m['end_date']),
      verified: (m['verified'] is bool) ? (m['verified'] as bool) : true,
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

// tiny helper for nullable title mapping
extension _StrX on String {
  String? takeIf(bool Function(String) pred) => pred(this) ? this : null;
}
