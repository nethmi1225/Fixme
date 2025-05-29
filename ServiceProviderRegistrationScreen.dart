import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceProviderRegistrationScreen extends StatefulWidget {
  const ServiceProviderRegistrationScreen({super.key});

  @override
  _ServiceProviderRegistrationScreenState createState() =>
      _ServiceProviderRegistrationScreenState();
}

class _ServiceProviderRegistrationScreenState
    extends State<ServiceProviderRegistrationScreen> {
  final _experienceController = TextEditingController();
  final _locationController = TextEditingController();
  final _workingAreasController = TextEditingController();
  final _rateController = TextEditingController();
  final _bioController = TextEditingController();
  final _skillsController = TextEditingController();
  final _additionalServicesController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _bankAccountController = TextEditingController();

  String? _selectedCategory;
  String? _selectedPaymentType;

  final List<String> _categories = [
    'Plumbing',
    'Electrical',
    'Mechanic',
    'Cleaning',
    'Painting',
    'A/C Repair',
    'Painter',
    'Meson',
    'Caregiver',
    'Home appliance repairing',
  ];
  final List<String> _paymentTypes = ['Hourly', 'Square Feet', 'Fixed Rate'];

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _experienceController.dispose();
    _locationController.dispose();
    _workingAreasController.dispose();
    _rateController.dispose();
    _bioController.dispose();
    _skillsController.dispose();
    _additionalServicesController.dispose();
    _businessNameController.dispose();
    _bankAccountController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      if (mounted) {
        _showSnackBar('User not authenticated');
      }
      return;
    }

    if (_experienceController.text.isEmpty ||
        _locationController.text.isEmpty ||
        _workingAreasController.text.isEmpty ||
        _rateController.text.isEmpty ||
        _selectedCategory == null ||
        _selectedPaymentType == null ||
        _bankAccountController.text.isEmpty) {
      if (mounted) {
        _showSnackBar('Please fill all required fields');
      }
      return;
    }

    try {
      final experience = double.parse(_experienceController.text);
      final rate = double.parse(_rateController.text);

      if (experience < 0 || rate < 0) {
        if (mounted) {
          _showSnackBar('Experience and rate must be positive numbers');
        }
        return;
      }

      String normalizedPaymentType;
      switch (_selectedPaymentType) {
        case 'Hourly':
          normalizedPaymentType = 'hourly';
          break;
        case 'Square Feet':
          normalizedPaymentType = 'squarefeet';
          break;
        case 'Fixed Rate':
          normalizedPaymentType = 'fixedrate';
          break;
        default:
          normalizedPaymentType = 'fixedrate';
      }

      await FirebaseDatabase.instance.ref('users/${firebaseUser.uid}').update({
        'role': 'pending_service_provider',
        'serviceProviderDetails': {
          'status': 'pending',
          'category': _selectedCategory,
          'experience': experience,
          'location': _locationController.text,
          'workingAreas':
              _workingAreasController.text.split(',').map((e) => e.trim()).toList(),
          'payment_type': normalizedPaymentType,
          'rate': rate,
          'businessName': _businessNameController.text,
          'bio': _bioController.text,
          'skills': _skillsController.text,
          'additionalServices': _additionalServicesController.text,
          'bankAccount': _bankAccountController.text,
        },
      });

      if (mounted) {
        _showSnackBar('Profile submitted! Awaiting admin approval.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error submitting profile: $e');
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    if (scaffoldMessenger == null) return;
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Roboto'),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        backgroundColor: const Color(0xFF00C4B4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF0DC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00C4B4),
        title: const Text(
          'Service Provider Registration',
          style: TextStyle(
            fontFamily: 'londonbridgefontfamily',
            fontSize: 22,
            color: Color.fromARGB(255, 255, 251, 37),
          ),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0F8FF),
              Color(0xFFE6F3FA),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal Information',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF131010),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _locationController,
                label: 'Location *',
                icon: Icons.location_on,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _workingAreasController,
                label: 'Working Areas (comma-separated) *',
                hint: 'e.g., Colombo, Kandy',
                icon: Icons.map,
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.grey, thickness: 0.5),
              const SizedBox(height: 24),
              const Text(
                'Service Details',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF131010),
                ),
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                value: _selectedCategory,
                label: 'Category *',
                items: _categories,
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
                icon: Icons.build,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _experienceController,
                label: 'Experience (years) *',
                icon: Icons.work_history,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _skillsController,
                label: 'Skills',
                icon: Icons.handyman,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _bioController,
                label: 'Bio',
                icon: Icons.description,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _additionalServicesController,
                label: 'Additional Services',
                icon: Icons.add_circle,
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.grey, thickness: 0.5),
              const SizedBox(height: 24),
              const Text(
                'Business & Payment',
                style: TextStyle(
                  fontFamily: 'Lato',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF131010),
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _businessNameController,
                label: 'Business Name',
                icon: Icons.business,
              ),
              const SizedBox(height: 16),
              _buildDropdownField(
                value: _selectedPaymentType,
                label: 'Payment Type *',
                items: _paymentTypes,
                onChanged: (value) {
                  setState(() {
                    _selectedPaymentType = value;
                  });
                },
                icon: Icons.payment,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _rateController,
                label: 'Rate *',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _bankAccountController,
                label: 'Bank Account Number *',
                icon: Icons.account_balance,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 40),
              Center(
                child: ElevatedButton(
                  onPressed: _submitRegistration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00C4B4),
                    foregroundColor: const Color(0xFF131010),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    'Submit Registration',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF5FBFF),
            Color(0xFFE8F4FA),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          color: Color(0xFF131010),
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            color: Colors.grey,
          ),
          hintStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            color: Colors.grey,
          ),
          prefixIcon: icon != null
              ? Icon(
                  icon,
                  color: const Color(0xFF00C4B4),
                  size: 20,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF00C4B4),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF5FBFF),
            Color(0xFFE8F4FA),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 16,
            color: Colors.grey,
          ),
          prefixIcon: icon != null
              ? Icon(
                  icon,
                  color: const Color(0xFF00C4B4),
                  size: 20,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF00C4B4),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(
              item,
              style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                color: Color(0xFF131010),
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        dropdownColor: const Color(0xFFF5FBFF),
        icon: const Icon(
          Icons.arrow_drop_down,
          color: Color(0xFF00C4B4),
        ),
      ),
    );
  }
}