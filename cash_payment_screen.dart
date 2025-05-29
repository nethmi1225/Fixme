import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'review_screen.dart';

class CashPaymentScreen extends StatefulWidget {
  final String bookingId;
  final String providerId;
  final String providerName;
  final String category;
  final double totalAmount;
  final String billingId;

  const CashPaymentScreen({
    super.key,
    required this.bookingId,
    required this.providerId,
    required this.providerName,
    required this.category,
    required this.totalAmount,
    required this.billingId,
  });

  @override
  _CashPaymentScreenState createState() => _CashPaymentScreenState();
}

class _CashPaymentScreenState extends State<CashPaymentScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _mismatchCount = 0; // Track mismatch attempts
  bool _isSuggestedAmountAccepted = false; // Track if suggested amount is accepted

  final double platformFeePercentage = 0.02; // 2% platform fee

  // Standardized rates for Sri Lanka
  final Map<String, double> _standardRates = {
    'hourly': 1000.0, // LKR 1,000 per hour
    'squarefeet': 100.0, // LKR 100 per square foot
    'fixedrate': 3000.0, // LKR 3,000 per job
  };

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

  Future<String> _getProviderPaymentType() async {
    final providerSnapshot = await FirebaseDatabase.instance
        .ref('users/${widget.providerId}/serviceProviderDetails')
        .get();
    if (providerSnapshot.exists) {
      final providerData = providerSnapshot.value as Map<dynamic, dynamic>;
      return providerData['payment_type'] as String? ?? 'fixedrate';
    }
    return 'fixedrate'; // Default fallback
  }

  Future<void> _showSuggestionDialog(double suggestedAmount, String paymentType) async {
    final platformFee = suggestedAmount * platformFeePercentage;
    final netAmount = suggestedAmount - platformFee;

    final accept = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suggested Amount', style: TextStyle(fontFamily: 'Poppins')),
        content: Text(
          'The entered amount does not match the expected total. Based on standard rates in Sri Lanka for $paymentType billing, we suggest:\n\n'
          'Suggested Total: ${suggestedAmount.toStringAsFixed(2)} LKR\n'
          'Platform Fee (2%): ${platformFee.toStringAsFixed(2)} LKR\n'
          'Net Amount to Provider: ${netAmount.toStringAsFixed(2)} LKR\n\n'
          'Would you like to use this amount?',
          style: const TextStyle(fontFamily: 'Roboto'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retry', style: TextStyle(fontFamily: 'Roboto')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Accept', style: TextStyle(fontFamily: 'Roboto', color: Color(0xFF00C4B4))),
          ),
        ],
      ),
    );

    if (accept == true) {
      setState(() {
        _amountController.text = suggestedAmount.toStringAsFixed(2);
        _mismatchCount = 0; // Reset mismatch count on acceptance
        _isSuggestedAmountAccepted = true; // Mark suggested amount as accepted
      });
      _showSnackBar('Suggested amount accepted. Please confirm payment.');
    }
  }

  Future<void> _confirmPayment(BuildContext context) async {
    final enteredAmount = double.tryParse(_amountController.text) ?? 0.0;

    if (!_isSuggestedAmountAccepted && enteredAmount != widget.totalAmount) {
      setState(() {
        _mismatchCount++;
      });

      _showSnackBar('Error: Entered amount does not match the total amount.');

      // Notify admin about the mismatch
      final adminNotificationRef = FirebaseDatabase.instance.ref('admin_notifications').push();
      await adminNotificationRef.set({
        'timestamp': DateTime.now().toIso8601String(),
        'message': 'Mismatch detected for provider ${widget.providerId} (${widget.providerName}). '
            'Entered: $enteredAmount LKR, Expected: ${widget.totalAmount} LKR.',
        'providerId': widget.providerId,
        'providerName': widget.providerName,
        'action': 'review',
        'status': 'pending',
      });

      // On second mismatch, suggest a standardized amount
      if (_mismatchCount >= 2) {
        final paymentType = await _getProviderPaymentType();
        final suggestedAmount = _standardRates[paymentType] ?? _standardRates['fixedrate']!;
        await _showSuggestionDialog(suggestedAmount, paymentType);
      }
      return;
    }

    // Use enteredAmount for calculations if suggested amount is accepted
    final paymentAmount = _isSuggestedAmountAccepted ? enteredAmount : widget.totalAmount;
    final platformFee = paymentAmount * platformFeePercentage;
    final netAmount = paymentAmount - platformFee;

    // Notify admin if suggested amount is used
    if (_isSuggestedAmountAccepted) {
      final adminNotificationRef = FirebaseDatabase.instance.ref('admin_notifications').push();
      await adminNotificationRef.set({
        'timestamp': DateTime.now().toIso8601String(),
        'message': 'Provider ${widget.providerId} (${widget.providerName}) payment adjusted. '
            'Original: ${widget.totalAmount.toStringAsFixed(2)} LKR, Accepted: ${paymentAmount.toStringAsFixed(2)} LKR '
            'due to repeated mismatch.',
        'providerId': widget.providerId,
        'providerName': widget.providerName,
        'action': 'review',
        'status': 'pending',
      });
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment', style: TextStyle(fontFamily: 'Poppins')),
        content: Text(
          'Total: ${paymentAmount.toStringAsFixed(2)} LKR\n'
          'Platform Fee (2%): ${platformFee.toStringAsFixed(2)} LKR\n'
          'Net Amount to Provider: ${netAmount.toStringAsFixed(2)} LKR\n'
          'Note: Platform fee will be deducted from the provider\'s bank account.',
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

      final providerSnapshot = await FirebaseDatabase.instance
          .ref('users/${widget.providerId}/serviceProviderDetails')
          .get();
      String bankAccount = 'Unknown';
      if (providerSnapshot.exists) {
        final providerData = providerSnapshot.value as Map<dynamic, dynamic>;
        bankAccount = providerData['bankAccount'] as String? ?? 'Unknown';
      }

      await FirebaseDatabase.instance.ref('billing/${widget.billingId}').update({
        'status': 'paid',
        'paymentMethod': 'cash',
        'platformFee': platformFee,
        'netAmount': netAmount,
        'providerBankAccount': bankAccount,
        'adjustedAmount': _isSuggestedAmountAccepted ? paymentAmount : null,
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
        'message': 'Customer $customerName has paid ${paymentAmount.toStringAsFixed(2)} LKR via cash. '
            'Platform fee of ${platformFee.toStringAsFixed(2)} LKR will be deducted from your bank account.'
            '${_isSuggestedAmountAccepted ? ' Note: Amount adjusted due to mismatch.' : ''}',
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
    _amountController.dispose();
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
          'Cash Payment',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cash on Delivery',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF131010),
                        ),
                      ),
                      const SizedBox(height: 24),
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
                      const SizedBox(height: 24),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: TextFormField(
                              controller: _amountController,
                              decoration: const InputDecoration(
                                labelText: 'Enter the Amount (LKR)',
                                labelStyle: TextStyle(fontFamily: 'OpenSans', color: Colors.grey),
                                border: OutlineInputBorder(borderSide: BorderSide.none),
                                enabledBorder: OutlineInputBorder(borderSide: BorderSide.none),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Color(0xFF00C4B4), width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.transparent,
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Please enter the amount';
                                final amount = double.tryParse(value);
                                if (amount == null) return 'Please enter a valid amount';
                                return null;
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
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
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text(
                            'Confirm Payment',
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

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'OpenSans',
            fontSize: 16,
            fontWeight:FontWeight.bold,
            color: Color(0xFF131010),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'OpenSans',
              fontSize: 16,
              color: Color(0xFF131010),
            ),
          ),
        ),
      ],
    );
  }
}