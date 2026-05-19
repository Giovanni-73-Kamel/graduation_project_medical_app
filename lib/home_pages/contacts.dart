import 'package:flutter/material.dart';
import 'package:medical/functions/app_colors.dart';
import 'package:medical/functions/custom_text.dart';
import 'package:medical/functions/txtfield.dart';
import 'package:medical/functions/settings_provider.dart';
import 'package:medical/home_pages/settings.dart';
import 'package:medical/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Contact> contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getContacts();
      setState(() {
        contacts = data.map((item) => Contact.fromJson(item)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        final s = SettingsScope.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.t('failed_load_contacts')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addContact() {
    final s = SettingsScope.of(context);
    final isDark = s.isDarkMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddContactSheet(
        isDark: isDark,
        onAdd: (contact) async {
          try {
            await ApiService.createContact(contact.toJson());
            await _loadContacts();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(s.t('contact_added')),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${s.t('failed_add_contact')}: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _editContact(int index) {
    final contact = contacts[index];
    final s = SettingsScope.of(context);
    final isDark = s.isDarkMode;

    if (contact.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.t('cannot_edit_missing_id')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddContactSheet(
        isDark: isDark,
        existingContact: contact,
        onAdd: (updated) async {
          try {
            await ApiService.updateContact(contact.id!, updated.toJson());
            await _loadContacts();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(s.t('contact_updated')),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${s.t('failed_update_contact')}: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _deleteContact(int index) async {
    final contact = contacts[index];
    final s = SettingsScope.of(context);

    if (contact.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.t('cannot_delete_missing_id')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      await ApiService.deleteContact(contact.id!);
      setState(() => contacts.removeAt(index));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.t('contact_deleted')),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${s.t('failed_delete_contact')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final isDark = s.isDarkMode;

    final bgColor = isDark ? const Color(0xFF0F1923) : Colors.grey[100]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white60 : Colors.grey[500]!;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomText(
                    text: s.t('contacts'),
                    color: textColor,
                    size: 28,
                    weight: FontWeight.bold,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: CustomText(
                      text: '${contacts.length} ${s.t('saved')}',
                      color: AppColors.primary,
                      size: 14,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : contacts.isEmpty
                      ? _buildEmptyState(subtextColor)
                      : RefreshIndicator(
                          onRefresh: _loadContacts,
                          child: ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: contacts.length,
                            itemBuilder: (context, index) {
                              return ContactCard(
                                contact: contacts[index],
                                isDark: isDark,
                                onEdit: () => _editContact(index),
                                onDelete: () => _deleteContact(index),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState(Color subtextColor) {
    final s = SettingsScope.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.contact_phone_outlined,
            size: 80,
            color: subtextColor.withOpacity(0.4),
          ),
          const SizedBox(height: 16),
          CustomText(
            text: s.t('no_contacts'),
            color: subtextColor,
            size: 16,
            weight: FontWeight.normal,
          ),
          const SizedBox(height: 8),
          CustomText(
            text: s.t('tap_add_contacts'),
            color: subtextColor.withOpacity(0.7),
            size: 14,
            weight: FontWeight.normal,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Contact model
// ─────────────────────────────────────────────

class Contact {
  final int? id;
  final String name;
  final String type;
  final String phone;
  final String email;

  Contact({
    this.id,
    required this.name,
    required this.type,
    required this.phone,
    required this.email,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'type': type,
        'phone': phone,
        'email': email,
      };

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['id'],
        name: json['name'] ?? '',
        type: json['type'] ?? 'Other',
        phone: json['phone'] ?? '',
        email: json['email'] ?? '',
      );
}

// ─────────────────────────────────────────────
// Helper methods for phone / email
// ─────────────────────────────────────────────

Future<void> _makePhoneCall(String phoneNumber) async {
  final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri);
  } else {
    debugPrint('Could not launch dialer');
  }
}

Future<void> _sendEmail(String email) async {
  final Uri launchUri = Uri(scheme: 'mailto', path: email);
  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri, mode: LaunchMode.externalApplication);
  } else {
    debugPrint('Could not launch email app');
  }
}

// ─────────────────────────────────────────────
// ContactCard — dark-mode aware
// ─────────────────────────────────────────────

class ContactCard extends StatelessWidget {
  final Contact contact;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ContactCard({
    super.key,
    required this.contact,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    Color typeColor;
    IconData typeIcon;

    switch (contact.type) {
      case 'Doctor':
        typeColor = Colors.green;
        typeIcon = Icons.medical_services;
        break;
      case 'Relative':
        typeColor = Colors.blue;
        typeIcon = Icons.family_restroom;
        break;
      default:
        typeColor = Colors.orange;
        typeIcon = Icons.person;
    }

    final cardBg = isDark ? const Color(0xFF1A2A3A) : Colors.white;
    final nameColor = isDark ? Colors.white : Colors.black87;
    final editIconColor = isDark ? Colors.white54 : Colors.grey[600]!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: typeColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Type icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(typeIcon, color: typeColor, size: 24),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomText(
                    text: contact.name,
                    color: nameColor,
                    size: 16,
                    weight: FontWeight.bold,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: CustomText(
                      text: contact.type,
                      color: typeColor,
                      size: 11,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Actions
            Row(
              children: [
                if (contact.phone.isNotEmpty)
                  IconButton(
                    onPressed: () => _makePhoneCall(contact.phone),
                    icon: const Icon(Icons.phone, color: Colors.green),
                    tooltip: 'Call',
                  ),
                if (contact.email.isNotEmpty)
                  IconButton(
                    onPressed: () => _sendEmail(contact.email),
                    icon: const Icon(Icons.email, color: Colors.blue),
                    tooltip: 'Email',
                  ),
                IconButton(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, color: editIconColor),
                  tooltip: 'Edit',
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: Icon(Icons.delete_outline, color: Colors.red[300]),
                  tooltip: 'Delete',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AddContactSheet — dark-mode aware + translated
// ─────────────────────────────────────────────

class AddContactSheet extends StatefulWidget {
  final Function(Contact) onAdd;
  final Contact? existingContact;
  final bool isDark;

  const AddContactSheet({
    super.key,
    required this.onAdd,
    required this.isDark,
    this.existingContact,
  });

  @override
  State<AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<AddContactSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String _selectedType = 'Relative';
  bool _isSaving = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.existingContact != null) {
      _nameController.text = widget.existingContact!.name;
      _phoneController.text = widget.existingContact!.phone;
      _emailController.text = widget.existingContact!.email;
      _selectedType = widget.existingContact!.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.existingContact != null;

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    final s = SettingsScope.of(context);

    if (_phoneController.text.trim().isEmpty &&
        _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('enter_phone_or_email'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    await widget.onAdd(Contact(
      name: _nameController.text.trim(),
      type: _selectedType,
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
    ));

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsScope.of(context);
    final isDark = widget.isDark;
    final sheetBg = isDark ? const Color(0xFF1A2A3A) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final borderColor =
        isDark ? Colors.white24 : Colors.grey.shade300;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CustomText(
                    text: _isEditing
                        ? s.t('edit_contact')
                        : s.t('add_contact'),
                    color: textColor,
                    size: 22,
                    weight: FontWeight.bold,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: textColor),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Type selection
              CustomText(
                text: s.t('relationship'),
                color: textColor,
                size: 14,
                weight: FontWeight.w600,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTypeChip('Relative', s.t('relative'), Colors.blue, isDark),
                  const SizedBox(width: 8),
                  _buildTypeChip('Doctor', s.t('doctor'), Colors.green, isDark),
                  const SizedBox(width: 8),
                  _buildTypeChip('Other', s.t('other'), Colors.orange, isDark),
                ],
              ),
              const SizedBox(height: 20),

              // Name
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CustomTxtfield(
                  controller: _nameController,
                  hint: s.t('name'),
                  isPassword: false,
                ),
              ),
              const SizedBox(height: 16),

              // Phone
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CustomTxtfield(
                  controller: _phoneController,
                  hint: s.t('phone_number'),
                  isPassword: false,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(height: 16),

              // Email
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CustomTxtfield(
                  controller: _emailController,
                  hint: s.t('email_address'),
                  isPassword: false,
                  keyboardType: TextInputType.emailAddress,
                ),
              ),
              const SizedBox(height: 24),

              // Save / Update button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _isEditing
                              ? s.t('update_contact')
                              : s.t('save_contact'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(
      String type, String label, Color color, bool isDark) {
    final isSelected = _selectedType == type;
    final unselectedBg = isDark ? const Color(0xFF0F1923) : Colors.white;
    final unselectedText = isDark ? Colors.white60 : Colors.grey[700]!;
    final unselectedBorder =
        isDark ? Colors.white24 : Colors.grey[300]!;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : unselectedBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : unselectedBorder,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : unselectedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}