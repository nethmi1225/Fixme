import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'review_screen.dart';

class CardPaymentScreen extends StatefulWidget {
  final String bookingId;
  final String providerId;
  final String providerName;
  final String category;
  final double totalAmount;
  final String billingId;

  const CardPaymentScreen({
    super.key,
    required this.bookingId,
    required this.providerId,
    required this.providerName,
    required this.category,
    required this.totalAmount,
    required this.billingId,
  });

  @override
  _CardPaymentScreenState createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _cardNumberController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();
  final TextEditingController _cvvController = TextEditingController();
  bool _saveCard = false;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final double platformFeePercentage = 0.02; // 2% platform fee

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  Future<void> _confirmPayment(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final platformFee = widget.totalAmount * platformFeePercentage;
    final netAmount = widget.totalAmount - platformFee;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment', style: TextStyle(fontFamily: 'Poppins')),
        content: Text(
          'Total: ${widget.totalAmount.toStringAsFixed(2)} LKR\n'
          'Platform Fee (2%): ${platformFee.toStringAsFixed(2)} LKR\n'
          'Net Amount to Provider: ${netAmount.toStringAsFixed(2)} LKR',
          style: const TextStyle(fontFamily: 'Roboto'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Roboto')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm', style: TextStyle(fontFamily: 'Roboto', color: Color(0xFF00C4B4))),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('User not authenticated.');
        setState(() {
          _isLoading = false;
        });
        return;
      }
      final userId = user.uid;

      final providerSnapshot = await FirebaseDatabase.instance.ref('users/${widget.providerId}/serviceProviderDetails').get();
      String bankAccount = 'Unknown';
      if (providerSnapshot.exists) {
        final providerData = providerSnapshot.value as Map<dynamic, dynamic>;
        bankAccount = providerData['bankAccount'] as String? ?? 'Unknown';
      }

      await FirebaseDatabase.instance.ref('billing/${widget.billingId}').update({
        'status': 'paid',
        'paymentMethod': 'card',
        'platformFee': platformFee,
        'netAmount': netAmount,
        'providerBankAccount': bankAccount,
      });

      final userSnapshot = await FirebaseDatabase.instance.ref('users/$userId').get();
      String customerName = 'Unknown';
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>;
        customerName = userData['firstName'] as String? ?? 'Unknown';
      }

      await FirebaseDatabase.instance.ref('notifications/${widget.providerId}').push().set({
        'user_id': userId,
        'category': widget.category,
        'status': 'Paid',
        'timestamp': DateTime.now().toIso8601String(),
        'customer_name': customerName,
        'message': 'Customer $customerName has paid ${netAmount.toStringAsFixed(2)} LKR (after 2% platform fee) via card.',
      });

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ReviewScreen(
            providerId: widget.providerId,
            providerName: widget.providerName,
          ),
        ),
      );

      _showSnackBar('Payment completed successfully!');
    } catch (e) {
      _showSnackBar('Error completing payment: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Roboto')),
        backgroundColor: const Color(0xFF00C4B4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryDateController.dispose();
    _cvvController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platformFee = widget.totalAmount * platformFeePercentage;
    final netAmount = widget.totalAmount - platformFee;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00C4B4),
        elevation: 0,
        title: const Text(
          'Card Payment',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFE0F7F5)],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Credit/Debit Card',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF131010),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Image.asset('assets/visa_icon.png', width: 40),
                            Image.asset('assets/mastercard_icon.png', width: 40),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          controller: _cardNumberController,
                          label: 'Card Number',
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please enter card number';
                            if (value.length != 16) return 'Card number must be 16 digits';
                            return null;
                          },
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _expiryDateController,
                                label: 'MM/YY',
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please enter expiry date';
                                  if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(value)) {
                                    return 'Enter valid MM/YY';
                                  }
                                  return null;
                                },
                                keyboardType: TextInputType.datetime,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTextField(
                                controller: _cvvController,
                                label: 'CVV',
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Please enter CVV';
                                  if (value.length != 3) return 'CVV must be 3 digits';
                                  return null;
                                },
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: _saveCard,
                              onChanged: (value) {
                                setState(() {
                                  _saveCard = value ?? false;
                                });
                              },
                              activeColor: const Color(0xFF00C4B4),
                            ),
                            const Text(
                              'Save this card',
                              style: TextStyle(
                                fontFamily: 'Open Sans',
                                fontSize: 16,
                                color: Color(0xFF131010),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFF8FAFC), Color(0xFFE0F7F5)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailRow('Service Provider', widget.providerName),
                                  const SizedBox(height: 12),
                                  _buildDetailRow('Category', widget.category),
                                  const SizedBox(height: 12),
                                  _buildDetailRow('Total Amount', '${widget.totalAmount.toStringAsFixed(2)} LKR'),
                                  const SizedBox(height: 12),
                                  _buildDetailRow('Platform Fee (2%)', '${platformFee.toStringAsFixed(2)} LKR'),
                                  const SizedBox(height: 12),
                                  _buildDetailRow('Net Amount to Provider', '${netAmount.toStringAsFixed(2)} LKR'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16), // Add some spacing at the bottom of the scrollable content
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C4B4)))
                    : Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF00C4B4), Color(0xFF00A1A7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => _confirmPayment(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                            minimumSize: const Size(double.infinity, 50), // Full-width button
                          ),
                          child: const Text(
                            'Make Payment',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    FormFieldValidator<String>? validator,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFC), Color(0xFFE0F7F5)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            // ignore: deprecated_member_use
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(fontFamily: 'Open Sans', color: Colors.grey),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00C4B4), width: 2),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'Open Sans',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF131010),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Open Sans',
              fontSize: 16,
              color: Color(0xFF131010),
            ),
          ),
        ),
      ],
    );
  }
}