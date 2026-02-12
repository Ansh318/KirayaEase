import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lease data model
class LeaseData {
  final String id;
  final String propertyAddress;
  final String? landlordName;
  final String? landlordPhone;
  final String? landlordEmail;
  final String? tenantName;
  final String? tenantPhone;
  final String? tenantAddress;
  final String? rentAmount;
  final String? startDate;
  final String? endDate;
  final String? propertyPincode;
  final DateTime createdAt;
  final Map<String, dynamic> rawData; // Store all extracted fields

  LeaseData({
    required this.id,
    required this.propertyAddress,
    this.landlordName,
    this.landlordPhone,
    this.landlordEmail,
    this.tenantName,
    this.tenantPhone,
    this.tenantAddress,
    this.rentAmount,
    this.startDate,
    this.endDate,
    this.propertyPincode,
    required this.createdAt,
    required this.rawData,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'property_address': propertyAddress,
        'landlord_name': landlordName,
        'landlord_phone': landlordPhone,
        'landlord_email': landlordEmail,
        'tenant_name': tenantName,
        'tenant_phone': tenantPhone,
        'tenant_address': tenantAddress,
        'rent_amount': rentAmount,
        'start_date': startDate,
        'end_date': endDate,
        'property_pincode': propertyPincode,
        'created_at': createdAt.toIso8601String(),
        'raw_data': rawData,
      };

  factory LeaseData.fromJson(Map<String, dynamic> json) => LeaseData(
        id: json['id'] as String,
        propertyAddress: json['property_address'] as String,
        landlordName: json['landlord_name'] as String?,
        landlordPhone: json['landlord_phone'] as String?,
        landlordEmail: json['landlord_email'] as String?,
        tenantName: json['tenant_name'] as String?,
        tenantPhone: json['tenant_phone'] as String?,
        tenantAddress: json['tenant_address'] as String?,
        rentAmount: json['rent_amount'] as String?,
        startDate: json['start_date'] as String?,
        endDate: json['end_date'] as String?,
        propertyPincode: json['property_pincode'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        rawData: json['raw_data'] as Map<String, dynamic>,
      );

  factory LeaseData.fromExtractedFields(Map<String, dynamic> fields) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    return LeaseData(
      id: id,
      propertyAddress: fields['property_address']?.toString() ?? 'Unknown Property',
      landlordName: fields['landlord_name']?.toString(),
      landlordPhone: fields['landlord_phone']?.toString(),
      landlordEmail: fields['landlord_email']?.toString(),
      tenantName: fields['tenant_name']?.toString(),
      tenantPhone: fields['tenant_phone']?.toString(),
      tenantAddress: fields['tenant_address']?.toString(),
      rentAmount: fields['rent_amount_inr']?.toString(),
      startDate: fields['start_date']?.toString(),
      endDate: fields['end_date']?.toString(),
      propertyPincode: fields['property_pincode']?.toString(),
      createdAt: DateTime.now(),
      rawData: fields,
    );
  }
}

/// Lease Store - Manages lease data state
class LeaseStore extends ChangeNotifier {
  static final LeaseStore _instance = LeaseStore._internal();
  factory LeaseStore() => _instance;
  LeaseStore._internal();

  List<LeaseData> _leases = [];
  bool _isLoading = false;

  List<LeaseData> get leases => List.unmodifiable(_leases);
  bool get isLoading => _isLoading;

  /// Initialize and load leases from storage
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _loadFromStorage();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a new lease
  Future<void> addLease(LeaseData lease) async {
    _leases.insert(0, lease); // Add to beginning
    notifyListeners();
    await _saveToStorage();
  }

  /// Remove a lease
  Future<void> removeLease(String id) async {
    _leases.removeWhere((lease) => lease.id == id);
    notifyListeners();
    await _saveToStorage();
  }

  /// Clear all leases
  Future<void> clearLeases() async {
    _leases.clear();
    notifyListeners();
    await _saveToStorage();
  }

  /// Load leases from SharedPreferences
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final leasesJson = prefs.getString('leases');
      if (leasesJson != null) {
        final List<dynamic> decoded = jsonDecode(leasesJson);
        _leases = decoded
            .map((json) => LeaseData.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Error loading leases: $e');
    }
  }

  /// Save leases to SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final leasesJson = jsonEncode(
        _leases.map((lease) => lease.toJson()).toList(),
      );
      await prefs.setString('leases', leasesJson);
    } catch (e) {
      print('Error saving leases: $e');
    }
  }
}
