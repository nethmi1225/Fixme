import 'package:flutter/material.dart';
import 'package:fixme_new/features/auth/presentation/views/cash_payment_screen.dart';
import 'package:fixme_new/features/auth/presentation/views/card_payment_screen.dart';

class PaymentMethodScreen extends StatefulWidget {
  final String bookingId;
  final String providerId;
  final String providerName;
  final String category;
  final double totalAmount;
  final String billingId;

  const PaymentMethodScreen({
    super.key,
    required this.bookingId,
    required this.providerId,
    required this.providerName,
    required this.category,
    required this.totalAmount,
    required this.billingId,
  });

  @override
  _PaymentMethodScreenState createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> with SingleTickerProviderStateMixin {
  String? _selectedMethod;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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

  void _navigateToPaymentScreen(BuildContext context, String method) {
    setState(() {
      _selectedMethod = method;
    });

    if (method == 'card') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CardPaymentScreen(
            bookingId: widget.bookingId,
            providerId: widget.providerId,
            providerName: widget.providerName,
            category: widget.category,
            totalAmount: widget.totalAmount,
            billingId: widget.billingId,
          ),
        ),
      );
    } else if (method == 'cash') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CashPaymentScreen(
            bookingId: widget.bookingId,
            providerId: widget.providerId,
            providerName: widget.providerName,
            category: widget.category,
            totalAmount: widget.totalAmount,
            billingId: widget.billingId,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Fallback background
      appBar: AppBar(
        backgroundColor: const Color(0xFF00C4B4),
        elevation: 0,
        title: const Text(
          'Payment',
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
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF131010),
                  ),
                ),
                const SizedBox(height: 24),
                _buildPaymentOption(
                  context,
                  'Pay with Card',
                  'card',
                  '2% platform fee deducted from payment',
                ),
                const SizedBox(height: 16),
                _buildPaymentOption(
                  context,
                  'Pay with Cash',
                  'cash',
                  '2% platform fee deducted from provider\'s bank account',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(BuildContext context, String title, String method, String subtitle) {
    bool isSelected = _selectedMethod == method;
    return GestureDetector(
      onTap: () => _navigateToPaymentScreen(context, method),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFE0F7F5)],
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: const Color(0xFF00C4B4),
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF131010),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontFamily: 'Open Sans',
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}