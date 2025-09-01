import 'package:flutter/material.dart';
import '../widgets/ai_assistant.dart'; // your existing chatbot widget

// =======================================================
// Property Management (Properties • Utilities • Leases)
// =======================================================

class PropertyPage extends StatefulWidget {
  const PropertyPage({super.key});

  @override
  State<PropertyPage> createState() => _PropertyPageState();
}

class _PropertyPageState extends State<PropertyPage> {
  // ----- Mock data -----
  final List<PropertyRow> _properties = [
    PropertyRow(
      name: 'Sunrise Apartments #204',
      address: '123 Palm St',
      city: 'Pune',
      rent: 12500,
      status: Occupancy.occupied,
    ),
    PropertyRow(
      name: 'Maple Residency 3B',
      address: '45 Maple Ave',
      city: 'Bengaluru',
      rent: 11500,
      status: Occupancy.vacant,
    ),
    PropertyRow(
      name: 'Oak Meadows 12A',
      address: '9 Oak Road',
      city: 'Mumbai',
      rent: 9800,
      status: Occupancy.occupied,
    ),
  ];

  final List<UtilityRow> _utilities = [
    UtilityRow(
      property: 'Sunrise Apartments #204',
      type: 'Electricity',
      provider: 'MSEDCL',
      account: 'ELC-88421',
      active: true,
    ),
    UtilityRow(
      property: 'Maple Residency 3B',
      type: 'Water',
      provider: 'BWSSB',
      account: 'WTR-22107',
      active: false,
    ),
    UtilityRow(
      property: 'Oak Meadows 12A',
      type: 'Internet',
      provider: 'Airtel Xstream',
      account: 'INT-55602',
      active: true,
    ),
  ];

  final List<LeaseRow> _leases = [
    LeaseRow(
      tenant: 'Sarah Johnson',
      property: 'Sunrise Apartments #204',
      period: '3/31/2024 - 3/30/2025',
      rent: 12500,
      deposit: 30000,
      status: LeaseStatus.active,
    ),
    LeaseRow(
      tenant: 'Alex Chen',
      property: 'Maple Residency 3B',
      period: '10/31/2023 - 10/30/2024',
      rent: 11500,
      deposit: 25000,
      status: LeaseStatus.expired,
    ),
    LeaseRow(
      tenant: 'Priya Kapoor',
      property: 'Oak Meadows 12A',
      period: '8/31/2024 - 8/30/2025',
      rent: 9800,
      deposit: 20000,
      status: LeaseStatus.endingSoon,
    ),
  ];

  // ----- Controllers / Filters -----
  final TextEditingController _propSearch = TextEditingController();
  final TextEditingController _utilSearch = TextEditingController();
  final TextEditingController _leaseSearch = TextEditingController();

  String? _cityFilter; // Properties
  String? _utilTypeFilter; // Utilities
  LeaseStatus? _leaseStatusFilter; // Leases

  int _activeTab = 0; // 0: Properties, 1: Utilities, 2: Leases

  @override
  void dispose() {
    _propSearch.dispose();
    _utilSearch.dispose();
    _leaseSearch.dispose();
    super.dispose();
  }

  // ----- Computed (overview) -----
  int get _totalProperties => _properties.length;
  int get _activeLeasesCount =>
      _leases.where((l) => l.status == LeaseStatus.active).length;
  int get _activeUtilitiesCount => _utilities.where((u) => u.active).length;

  // ----- Filtered Views -----
  List<PropertyRow> get _filteredProperties {
    final q = _propSearch.text.trim().toLowerCase();
    return _properties.where((r) {
      final matchesQuery = q.isEmpty ||
          r.name.toLowerCase().contains(q) ||
          r.address.toLowerCase().contains(q);
      final matchesCity = _cityFilter == null || r.city == _cityFilter;
      return matchesQuery && matchesCity;
    }).toList();
  }

  List<UtilityRow> get _filteredUtilities {
    final q = _utilSearch.text.trim().toLowerCase();
    return _utilities.where((r) {
      final matchesQuery = q.isEmpty ||
          r.property.toLowerCase().contains(q) ||
          r.provider.toLowerCase().contains(q) ||
          r.account.toLowerCase().contains(q);
      final matchesType = _utilTypeFilter == null || r.type == _utilTypeFilter;
      return matchesQuery && matchesType;
    }).toList();
  }

  List<LeaseRow> get _filteredLeases {
    final q = _leaseSearch.text.trim().toLowerCase();
    return _leases.where((r) {
      final matchesQuery = q.isEmpty ||
          r.tenant.toLowerCase().contains(q) ||
          r.property.toLowerCase().contains(q);
      final matchesStatus =
          _leaseStatusFilter == null || r.status == _leaseStatusFilter;
      return matchesQuery && matchesStatus;
    }).toList();
  }

  // ----- Actions -----
  Future<void> _openAddPropertySheet() async {
    final added = await showModalBottomSheet<PropertyRow>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddPropertySheet(),
    );
    if (added != null) {
      setState(() => _properties.add(added));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Property added')));
    }
  }

  Future<void> _openAddUtilitySheet() async {
    final added = await showModalBottomSheet<UtilityRow>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddUtilitySheet(
        propertyOptions: _properties.map((e) => e.name).toList(),
      ),
    );
    if (added != null) {
      setState(() => _utilities.add(added));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Utility added')));
    }
  }

  Future<void> _openAddLeaseSheet() async {
    final added = await showModalBottomSheet<LeaseRow>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddLeaseSheet(
        propertyOptions: _properties.map((e) => e.name).toList(),
      ),
    );
    if (added != null) {
      setState(() => _leases.add(added));
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Lease added')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF7FAFB);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        title: const Text('Portfolio Overview',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Overview cards (responsive)
                Row(
                  children: [
                    Expanded(
                      child: _OverviewCard(
                        label: 'Total Properties',
                        value: _totalProperties.toString(),
                        color: const Color(0xFFE9F7F1),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OverviewCard(
                        label: 'Active Leases',
                        value: _activeLeasesCount.toString(),
                        color: const Color(0xFFFFF3EA),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _OverviewCard(
                        label: 'Active Utilities',
                        value: _activeUtilitiesCount.toString(),
                        color: const Color(0xFFEFF6FF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Tabs (overflow-proof)
                _Tabs(
                  index: _activeTab,
                  onChanged: (i) => setState(() => _activeTab = i),
                ),
                const SizedBox(height: 16),

                if (_activeTab == 0)
                  ..._buildPropertiesTab() //
                else if (_activeTab == 1)
                  ..._buildUtilitiesTab() //
                else
                  ..._buildLeasesTab(),
              ],
            ),
          ),

          // Chatbot floating bottom-right (already built elsewhere)
          const AIAssistantChatWidget(),
        ],
      ),
    );
  }

  // ==================== TABS ====================

  List<Widget> _buildPropertiesTab() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Properties',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          _AddButton(onTap: _openAddPropertySheet, label: 'Add Property'),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _propSearch,
              onChanged: (_) => setState(() {}),
              decoration: _searchDecoration('Search by name or address'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _cityFilter,
              isExpanded: true,
              decoration: _dropdownDecoration('City'),
              items: <String?>{null, ..._properties.map((e) => e.city)}
                  .map((c) => DropdownMenuItem<String?>(
                      value: c, child: Text(c ?? 'All')))
                  .toList(),
              onChanged: (v) => setState(() => _cityFilter = v),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _dataCard(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Address')),
            DataColumn(label: Text('City')),
            DataColumn(label: Text('Rent')),
            DataColumn(label: Text('Status')),
          ],
          rows: _filteredProperties.map((r) {
            return DataRow(cells: [
              DataCell(Text(r.name)),
              DataCell(Text(r.address)),
              DataCell(Text(r.city)),
              DataCell(Text('₹${_formatMoney(r.rent)}')),
              DataCell(_StatusChip(status: r.status)),
            ]);
          }).toList(),
        ),
      ),
      const SizedBox(height: 14),
      const Center(
          child: Text('List of your properties.',
              style: TextStyle(color: Colors.black54))),
    ];
  }

  List<Widget> _buildUtilitiesTab() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Utilities',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          _AddButton(onTap: _openAddUtilitySheet, label: 'Add Utility'),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _utilSearch,
              onChanged: (_) => setState(() {}),
              decoration:
                  _searchDecoration('Search by property, provider, account'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: _utilTypeFilter,
              isExpanded: true,
              decoration: _dropdownDecoration('Type'),
              items: <String?>{null, ..._utilities.map((e) => e.type)}
                  .map((c) => DropdownMenuItem<String?>(
                      value: c, child: Text(c ?? 'All')))
                  .toList(),
              onChanged: (v) => setState(() => _utilTypeFilter = v),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _dataCard(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Property')),
            DataColumn(label: Text('Type')),
            DataColumn(label: Text('Provider')),
            DataColumn(label: Text('Account')),
            DataColumn(label: Text('Status')),
          ],
          rows: _filteredUtilities.map((r) {
            return DataRow(cells: [
              DataCell(Text(r.property)),
              DataCell(Text(r.type)),
              DataCell(Text(r.provider)),
              DataCell(Text(r.account)),
              DataCell(_Pill(
                text: r.active ? 'Active' : 'Inactive',
                bg: r.active
                    ? const Color(0xFFE7FAEE)
                    : const Color(0xFFF4ECFF),
                fg: r.active
                    ? const Color(0xFF0F8A44)
                    : const Color(0xFF6E59A5),
              )),
            ]);
          }).toList(),
        ),
      ),
      const SizedBox(height: 14),
      const Center(
        child: Text('Utilities linked to your properties.',
            style: TextStyle(color: Colors.black54)),
      ),
    ];
  }

  List<Widget> _buildLeasesTab() {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Lease Agreements',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          _AddButton(onTap: _openAddLeaseSheet, label: 'New Lease'),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              controller: _leaseSearch,
              onChanged: (_) => setState(() {}),
              decoration: _searchDecoration('Search by tenant or property'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<LeaseStatus?>(
              value: _leaseStatusFilter,
              isExpanded: true,
              decoration: _dropdownDecoration('Lease status'),
              items: const [
                DropdownMenuItem<LeaseStatus?>(value: null, child: Text('All')),
                DropdownMenuItem<LeaseStatus?>(
                    value: LeaseStatus.active, child: Text('Active')),
                DropdownMenuItem<LeaseStatus?>(
                    value: LeaseStatus.expired, child: Text('Expired')),
                DropdownMenuItem<LeaseStatus?>(
                    value: LeaseStatus.endingSoon, child: Text('Ending soon')),
              ],
              onChanged: (v) => setState(() => _leaseStatusFilter = v),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _dataCard(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Tenant')),
            DataColumn(label: Text('Property')),
            DataColumn(label: Text('Period')),
            DataColumn(label: Text('Rent')),
            DataColumn(label: Text('Deposit')),
            DataColumn(label: Text('Status')),
          ],
          rows: _filteredLeases.map((r) {
            final pill = switch (r.status) {
              LeaseStatus.active => _Pill(
                  text: 'Active',
                  bg: const Color(0xFFE7FAEE),
                  fg: const Color(0xFF0F8A44),
                ),
              LeaseStatus.expired => _Pill(
                  text: 'Expired',
                  bg: const Color(0xFFFFEDEC),
                  fg: const Color(0xFFB42318),
                ),
              LeaseStatus.endingSoon => _Pill(
                  text: 'Ending soon',
                  bg: const Color(0xFFFFF3E6),
                  fg: const Color(0xFFB35B00),
                ),
            };
            return DataRow(cells: [
              DataCell(Text(r.tenant,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              DataCell(Text(r.property)),
              DataCell(Text(r.period)),
              DataCell(Text('₹${_formatMoney(r.rent)}')),
              DataCell(Text('₹${_formatMoney(r.deposit)}')),
              DataCell(pill),
            ]);
          }).toList(),
        ),
      ),
      const SizedBox(height: 14),
      const Center(
        child: Text('Current and past lease agreements.',
            style: TextStyle(color: Colors.black54)),
      ),
    ];
  }

  // ==================== Helpers ====================

  InputDecoration _searchDecoration(String hint) => InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );

  InputDecoration _dropdownDecoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      );

  Widget _dataCard({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: child,
        ),
      );

  String _formatMoney(num v) {
    // Indian grouping (##,##,###)
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buf.write(s[i]);
      count++;
      if (i > 0 && (count == 3 || (count > 3 && (count - 3) % 2 == 0))) {
        buf.write(',');
      }
    }
    return buf.toString().split('').reversed.join();
  }
}

// =======================================================
// Models
// =======================================================

enum Occupancy { occupied, vacant }

class PropertyRow {
  final String name;
  final String address;
  final String city;
  final int rent;
  final Occupancy status;

  PropertyRow({
    required this.name,
    required this.address,
    required this.city,
    required this.rent,
    required this.status,
  });
}

class UtilityRow {
  final String property;
  final String type; // Electricity / Water / Internet...
  final String provider;
  final String account;
  final bool active;

  UtilityRow({
    required this.property,
    required this.type,
    required this.provider,
    required this.account,
    required this.active,
  });
}

enum LeaseStatus { active, expired, endingSoon }

class LeaseRow {
  final String tenant;
  final String property;
  final String period; // "start - end"
  final int rent;
  final int deposit;
  final LeaseStatus status;

  LeaseRow({
    required this.tenant,
    required this.property,
    required this.period,
    required this.rent,
    required this.deposit,
    required this.status,
  });
}

// =======================================================
// UI Components
// =======================================================

class _OverviewCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _OverviewCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const _Tabs({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final items = const [
      (Icons.apartment_rounded, 'Properties'),
      (Icons.power_outlined, 'Utilities'),
      (Icons.description_outlined, 'Lease Agreements'),
    ];

    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFFF0ECF7),
          borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: List.generate(items.length, (i) {
          final selected = i == index;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => onChanged(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: FittedBox(
                  // ← prevents RIGHT overflow on small widths / large text scales
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(items[i].$1,
                          size: 18,
                          color: selected ? Colors.black : Colors.black54),
                      const SizedBox(width: 8),
                      Text(
                        items[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.black : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;
  const _AddButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add, size: 18),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Occupancy status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isOcc = status == Occupancy.occupied;
    return _Pill(
      text: isOcc ? 'Occupied' : 'Vacant',
      bg: isOcc ? const Color(0xFFE7FAEE) : const Color(0xFFFFEFE5),
      fg: isOcc ? const Color(0xFF0F8A44) : const Color(0xFFB35B00),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  const _Pill({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style:
              TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

// =======================================================
// Add Sheets
// =======================================================

class _AddPropertySheet extends StatefulWidget {
  const _AddPropertySheet();

  @override
  State<_AddPropertySheet> createState() => _AddPropertySheetState();
}

class _AddPropertySheetState extends State<_AddPropertySheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _rent = TextEditingController();
  Occupancy _status = Occupancy.occupied;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _rent.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final row = PropertyRow(
      name: _name.text.trim(),
      address: _address.text.trim(),
      city: _city.text.trim().isEmpty ? '—' : _city.text.trim(),
      rent: int.tryParse(_rent.text.trim()) ?? 0,
      status: _status,
    );
    Navigator.pop(context, row);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Add Property',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TField(
                controller: _name, label: 'Property Name', requiredField: true),
            _TField(controller: _address, label: 'Address'),
            _TField(controller: _city, label: 'City'),
            _TField(
                controller: _rent,
                label: 'Monthly Rent (₹)',
                keyboard: TextInputType.number),
            DropdownButtonFormField<Occupancy>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(
                    value: Occupancy.occupied, child: Text('Occupied')),
                DropdownMenuItem(
                    value: Occupancy.vacant, child: Text('Vacant')),
              ],
              onChanged: (v) =>
                  setState(() => _status = v ?? Occupancy.occupied),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: const Text('Add Property')),
          ],
        ),
      ),
    );
  }
}

class _AddUtilitySheet extends StatefulWidget {
  final List<String> propertyOptions;
  const _AddUtilitySheet({required this.propertyOptions});

  @override
  State<_AddUtilitySheet> createState() => _AddUtilitySheetState();
}

class _AddUtilitySheetState extends State<_AddUtilitySheet> {
  final _formKey = GlobalKey<FormState>();
  String? _property;
  String? _type;
  final _provider = TextEditingController();
  final _account = TextEditingController();
  bool _active = true;

  @override
  void dispose() {
    _provider.dispose();
    _account.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate() ||
        _property == null ||
        _type == null) return;
    Navigator.pop(
      context,
      UtilityRow(
        property: _property!,
        type: _type!,
        provider: _provider.text.trim(),
        account: _account.text.trim(),
        active: _active,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Add Utility',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _property,
              decoration: const InputDecoration(labelText: 'Property'),
              items: widget.propertyOptions
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _property = v),
            ),
            DropdownButtonFormField<String>(
              value: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(
                    value: 'Electricity', child: Text('Electricity')),
                DropdownMenuItem(value: 'Water', child: Text('Water')),
                DropdownMenuItem(value: 'Internet', child: Text('Internet')),
                DropdownMenuItem(value: 'Gas', child: Text('Gas')),
              ],
              onChanged: (v) => setState(() => _type = v),
            ),
            _TField(controller: _provider, label: 'Provider'),
            _TField(controller: _account, label: 'Account'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: const Text('Add Utility')),
          ],
        ),
      ),
    );
  }
}

class _AddLeaseSheet extends StatefulWidget {
  final List<String> propertyOptions;
  const _AddLeaseSheet({required this.propertyOptions});

  @override
  State<_AddLeaseSheet> createState() => _AddLeaseSheetState();
}

class _AddLeaseSheetState extends State<_AddLeaseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tenant = TextEditingController();
  String? _property;
  final _period = TextEditingController();
  final _rent = TextEditingController();
  final _deposit = TextEditingController();
  LeaseStatus _status = LeaseStatus.active;

  @override
  void dispose() {
    _tenant.dispose();
    _period.dispose();
    _rent.dispose();
    _deposit.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _property == null) return;
    Navigator.pop(
      context,
      LeaseRow(
        tenant: _tenant.text.trim(),
        property: _property!,
        period: _period.text.trim(),
        rent: int.tryParse(_rent.text.trim()) ?? 0,
        deposit: int.tryParse(_deposit.text.trim()) ?? 0,
        status: _status,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'New Lease',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _TField(controller: _tenant, label: 'Tenant', requiredField: true),
            DropdownButtonFormField<String>(
              value: _property,
              decoration: const InputDecoration(labelText: 'Property'),
              items: widget.propertyOptions
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _property = v),
            ),
            _TField(
                controller: _period,
                label: 'Period (e.g., 1/1/2025 - 12/31/2025)'),
            _TField(
                controller: _rent,
                label: 'Rent (₹)',
                keyboard: TextInputType.number),
            _TField(
                controller: _deposit,
                label: 'Deposit (₹)',
                keyboard: TextInputType.number),
            DropdownButtonFormField<LeaseStatus>(
              value: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(
                    value: LeaseStatus.active, child: Text('Active')),
                DropdownMenuItem(
                    value: LeaseStatus.expired, child: Text('Expired')),
                DropdownMenuItem(
                    value: LeaseStatus.endingSoon, child: Text('Ending soon')),
              ],
              onChanged: (v) =>
                  setState(() => _status = v ?? LeaseStatus.active),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.check),
                label: const Text('Save Lease')),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// Sheet Scaffolding + Inputs
// =======================================================

class _SheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  const _SheetScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      minChildSize: 0.45,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: ListView(
          controller: controller,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _TField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboard;
  final bool requiredField;
  const _TField({
    required this.controller,
    required this.label,
    this.keyboard,
    this.requiredField = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
        validator: (v) {
          if (requiredField && (v == null || v.trim().isEmpty)) {
            return 'Enter $label';
          }
          return null;
        },
      ),
    );
  }
}
