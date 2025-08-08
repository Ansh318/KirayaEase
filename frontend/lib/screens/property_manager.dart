// import 'package:flutter/material.dart';

// class PropertyPage extends StatefulWidget {
//   const PropertyPage({super.key});

//   @override
//   State<PropertyPage> createState() => _PropertyPageState();
// }

// class _PropertyPageState extends State<PropertyPage> {
//   List<Map<String, String>> properties = [];

//   void _openAddPropertySheet() async {
//     final result = await showModalBottomSheet<Map<String, String>>(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => const AddPropertyModal(),
//     );

//     if (result != null) {
//       setState(() => properties.add(result));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("Manage Properties"),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.add_business_rounded),
//             onPressed: _openAddPropertySheet,
//           ),
//         ],
//       ),
//       body: properties.isEmpty
//           ? const Center(
//               child: Text(
//                 "No properties yet. Tap '+' to add one.",
//                 style: TextStyle(fontSize: 16),
//               ),
//             )
//           : ListView.builder(
//               itemCount: properties.length,
//               itemBuilder: (ctx, index) {
//                 final prop = properties[index];
//                 return Card(
//                   margin: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 8,
//                   ),
//                   child: ListTile(
//                     title: Text(prop["name"] ?? "Unnamed"),
//                     subtitle: Text(prop["address"] ?? "No address"),
//                     trailing: Text("₹${prop["rent"]}/mo"),
//                     onTap: () {
//                       // TODO: Navigate to lease management for this property
//                     },
//                   ),
//                 );
//               },
//             ),
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: _openAddPropertySheet,
//         icon: const Icon(Icons.add),
//         label: const Text("Add Property"),
//       ),
//     );
//   }
// }

// class AddPropertyModal extends StatefulWidget {
//   const AddPropertyModal({super.key});

//   @override
//   State<AddPropertyModal> createState() => _AddPropertyModalState();
// }

// class _AddPropertyModalState extends State<AddPropertyModal> {
//   final _formKey = GlobalKey<FormState>();
//   final Map<String, String> _formData = {"name": "", "address": "", "rent": ""};

//   void _submitForm() {
//     if (_formKey.currentState!.validate()) {
//       _formKey.currentState!.save();
//       Navigator.pop(context, _formData);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return DraggableScrollableSheet(
//       initialChildSize: 0.65,
//       maxChildSize: 0.9,
//       minChildSize: 0.45,
//       builder: (_, controller) => Container(
//         padding: const EdgeInsets.all(24),
//         decoration: const BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
//         ),
//         child: Form(
//           key: _formKey,
//           child: ListView(
//             controller: controller,
//             children: [
//               const Text(
//                 "Add New Property",
//                 style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
//               ),
//               const SizedBox(height: 20),
//               TextFormField(
//                 decoration: const InputDecoration(labelText: "Property Name"),
//                 onSaved: (val) => _formData["name"] = val ?? '',
//                 validator: (val) =>
//                     val == null || val.isEmpty ? "Enter property name" : null,
//               ),
//               const SizedBox(height: 12),
//               TextFormField(
//                 decoration: const InputDecoration(labelText: "Address"),
//                 onSaved: (val) => _formData["address"] = val ?? '',
//                 validator: (val) =>
//                     val == null || val.isEmpty ? "Enter address" : null,
//               ),
//               const SizedBox(height: 12),
//               TextFormField(
//                 decoration: const InputDecoration(
//                   labelText: "Monthly Rent (₹)",
//                 ),
//                 keyboardType: TextInputType.number,
//                 onSaved: (val) => _formData["rent"] = val ?? '',
//                 validator: (val) =>
//                     val == null || val.isEmpty ? "Enter monthly rent" : null,
//               ),
//               const SizedBox(height: 24),
//               ElevatedButton.icon(
//                 onPressed: _submitForm,
//                 icon: const Icon(Icons.check),
//                 label: const Text("Add Property"),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/ai_assistant.dart';

class PropertyPage extends StatefulWidget {
  const PropertyPage({super.key});

  @override
  State<PropertyPage> createState() => _PropertyPageState();
}

class _PropertyPageState extends State<PropertyPage> {
  // now each property can hold its own list of leases
  List<Map<String, dynamic>> properties = [];

  /// opens the sheet to add a new property
  void _openAddPropertySheet() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddPropertyModal(),
    );

    if (result != null) {
      setState(() {
        properties.add({
          'name': result['name']!,
          'address': result['address']!,
          'rent': result['rent']!,
          'leases': <Map<String, String>>[],
        });
      });
    }
  }

  /// opens the sheet to attach a lease to property at [index]
  void _openAddLeaseSheet(int index) async {
    final propName = properties[index]['name'];
    final lease = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddLeaseModal(propertyName: propName),
    );
    if (lease != null) {
      setState(() {
        properties[index]['leases'].add(lease);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lease added for "$propName"')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Properties"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_business_rounded),
            onPressed: _openAddPropertySheet,
          ),
        ],
      ),

      // 1) your AI assistant, pinned bottom-right
      floatingActionButton: const AIAssistantChatWidget(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

      body: properties.isEmpty
          ? const Center(
              child: Text(
                "No properties yet.\nTap '+' to add one.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: properties.length,
              itemBuilder: (ctx, index) {
                final prop = properties[index];
                final leases = prop['leases'] as List<Map<String, String>>;
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(prop["name"] ?? "Unnamed"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(prop["address"] ?? "No address"),
                        const SizedBox(height: 4),
                        Text("₹${prop["rent"]}/mo"),
                        if (leases.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            "Leases: ${leases.length}",
                            style: const TextStyle(
                                fontSize: 12, color: Colors.black54),
                          )
                        ]
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.description_outlined),
                      tooltip: "Attach Lease",
                      onPressed: () => _openAddLeaseSheet(index),
                    ),
                    onTap: () {
                      // TODO: expand to view/manage existing leases
                    },
                  ),
                );
              },
            ),
    );
  }
}

/// bottom‐sheet form for adding a new property
class AddPropertyModal extends StatefulWidget {
  const AddPropertyModal({super.key});

  @override
  State<AddPropertyModal> createState() => _AddPropertyModalState();
}

class _AddPropertyModalState extends State<AddPropertyModal> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _formData = {"name": "", "address": "", "rent": ""};

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      Navigator.pop(context, _formData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.9,
      minChildSize: 0.45,
      builder: (_, controller) => Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          // allow for keyboard
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(controller: controller, children: [
            const Text(
              "Add New Property",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              decoration: const InputDecoration(labelText: "Property Name"),
              onSaved: (val) => _formData["name"] = val ?? '',
              validator: (val) =>
                  val == null || val.isEmpty ? "Enter property name" : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(labelText: "Address"),
              onSaved: (val) => _formData["address"] = val ?? '',
              validator: (val) =>
                  val == null || val.isEmpty ? "Enter address" : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                labelText: "Monthly Rent (₹)",
              ),
              keyboardType: TextInputType.number,
              onSaved: (val) => _formData["rent"] = val ?? '',
              validator: (val) =>
                  val == null || val.isEmpty ? "Enter monthly rent" : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _submitForm,
              icon: const Icon(Icons.check),
              label: const Text("Add Property"),
            ),
          ]),
        ),
      ),
    );
  }
}

/// bottom‐sheet form for attaching a lease to a specific property
class AddLeaseModal extends StatefulWidget {
  final String propertyName;
  const AddLeaseModal({super.key, required this.propertyName});

  @override
  State<AddLeaseModal> createState() => _AddLeaseModalState();
}

class _AddLeaseModalState extends State<AddLeaseModal> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, String> _leaseData = {
    "tenant": "",
    "startDate": "",
    "endDate": "",
  };

  void _submitLease() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      Navigator.pop(context, _leaseData);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.85,
      minChildSize: 0.3,
      builder: (_, controller) => Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(controller: controller, children: [
            Text(
              "Attach Lease to\n${widget.propertyName}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              decoration: const InputDecoration(labelText: "Tenant Name"),
              onSaved: (val) => _leaseData["tenant"] = val ?? '',
              validator: (val) =>
                  val == null || val.isEmpty ? "Enter tenant name" : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(labelText: "Start Date"),
              onSaved: (val) => _leaseData["startDate"] = val ?? '',
              validator: (val) =>
                  val == null || val.isEmpty ? "Enter start date" : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(labelText: "End Date"),
              onSaved: (val) => _leaseData["endDate"] = val ?? '',
              validator: (val) =>
                  val == null || val.isEmpty ? "Enter end date" : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _submitLease,
              icon: const Icon(Icons.check),
              label: const Text("Attach Lease"),
            ),
          ]),
        ),
      ),
    );
  }
}
