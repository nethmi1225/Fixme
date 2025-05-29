import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:fixme_new/features/auth/presentation/views/success_screen.dart' as success;
import 'package:fixme_new/features/auth/presentation/views/otp_screen.dart';

class PhoneInputScreen extends StatefulWidget {
  final String? initialPhoneNumber;
  const PhoneInputScreen({super.key, this.initialPhoneNumber});

  @override
  _PhoneInputScreenState createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen> {
  String phoneNumber = '';
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhoneNumber != null) {
      phoneNumber = widget.initialPhoneNumber!;
    }
  }

  void sendOTP() async {
    print('Attempting to send OTP to: $phoneNumber');
    if (phoneNumber.isEmpty) {
      print('Phone number is empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('Auto-verification completed: ${credential.smsCode}');
          await FirebaseAuth.instance.signInWithCredential(credential);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const success.SuccessScreen()),
            (route) => false, // Clear the stack
            // Return true to indicate successful verification
          ).then((_) => Navigator.pop(context, true));
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.message}, code: ${e.code}');
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          print('OTP sent, verificationId: $verificationId, resendToken: $resendToken');
          setState(() {
            isLoading = false;
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(
                phoneNumber: phoneNumber,
                verificationId: verificationId,
              ),
            ),
          ).then((result) {
            // If OTP verification was successful, pop with true
            if (result == true) {
              Navigator.pop(context, true);
            }
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Auto-retrieval timeout for verificationId: $verificationId');
        },
      );
    } catch (e) {
      print('Exception sending OTP: $e');
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending OTP: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              const Color(0xFF00C4B4).withOpacity(0.05),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: const Color(0xFF00C4B4),
                  child: const Icon(Icons.phone, size: 40, color: Colors.white),
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(curve: Curves.easeOut),
                const SizedBox(height: 20),
                const Text(
                  'Enter Your Phone Number',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF131010),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms, delay: 100.ms),
                const SizedBox(height: 10),
                const Text(
                  'We’ll send a verification code via SMS.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                const SizedBox(height: 20),
                IntlPhoneField(
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '7XXXXXXXX',
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00C4B4)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF00C4B4), width: 2),
                    ),
                  ),
                  initialCountryCode: 'LK',
                  initialValue: widget.initialPhoneNumber, // Pre-fill phone number
                  onChanged: (phone) {
                    setState(() {
                      phoneNumber = phone.completeNumber;
                    });
                  },
                ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C4B4), Color(0xFF4DD0E1)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C4B4).withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: isLoading || phoneNumber.isEmpty ? null : sendOTP,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Send OTP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}