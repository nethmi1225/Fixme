import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:sms_autofill/sms_autofill.dart'; 
import 'success_screen.dart';

class OtpScreen extends StatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  _OtpScreenState createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  TextEditingController otpController = TextEditingController();
  bool isButtonEnabled = false;
  bool isLoading = false;
  int resendTimer = 60;
  bool canResend = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    startResendTimer();
    _listenForCode();
  }

  void _listenForCode() async {
    await SmsAutoFill().listenForCode;
  }

  void startResendTimer() {
    setState(() {
      canResend = false;
      resendTimer = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendTimer == 0) {
        setState(() {
          canResend = true;
          timer.cancel();
        });
      } else {
        setState(() {
          resendTimer--;
        });
      }
    });
  }

  void resendOTP() async {
    if (!canResend) return;

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SuccessScreen()),
          );
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error resending OTP: ${e.message}')),
          );
        },
        codeSent: (String newVerificationId, int? resendToken) {
          setState(() {
            isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OTP resent successfully')),
          );
          startResendTimer();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(
                phoneNumber: widget.phoneNumber,
                verificationId: newVerificationId,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error resending OTP: $e')),
      );
    }
  }

  void verifyOTP() async {
    if (otpController.text.length != 6) return;

    setState(() {
      isLoading = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otpController.text,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Fetch user data to determine role
        final snapshot = await FirebaseDatabase.instance
            .ref('users/${user.uid}')
            .get();
        String role = 'customer';
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          role = data['role']?.toString() ?? 'customer';
        }

        // Update isPhoneVerified based on role
        final updates = {
          'isPhoneVerified': true,
        };
        print('Updating isPhoneVerified for user ${user.uid}');
        await FirebaseDatabase.instance
            .ref('users/${user.uid}')
            .update(updates);

        // If service provider, also update within serviceProviderDetails
        if (role == 'service_provider') {
          await FirebaseDatabase.instance
              .ref('users/${user.uid}/serviceProviderDetails')
              .update({'isPhoneVerified': true});
        }

        // Verify the update
        final updatedSnapshot = await FirebaseDatabase.instance
            .ref('users/${user.uid}/isPhoneVerified')
            .get();
        print('isPhoneVerified after update: ${updatedSnapshot.value}');

        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SuccessScreen()),
        );
        // Navigate back to ProfileScreen and refresh
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/profile',
          (Route<dynamic> route) => false,
          arguments: true, // Pass a flag to trigger refresh
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying OTP: $e')),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    otpController.dispose();
    SmsAutoFill().unregisterListener();
    super.dispose();
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
                  child: const Icon(Icons.sms, size: 40, color: Colors.white),
                )
                    .animate()
                    .fadeIn(duration: 500.ms)
                    .scale(curve: Curves.easeOut),
                const SizedBox(height: 20),
                const Text(
                  'Enter the Verification Code',
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
                Text(
                  'Sent to ${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
                const SizedBox(height: 20),
                PinCodeTextField(
                  appContext: context,
                  length: 6,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      isButtonEnabled = value.length == 6;
                    });
                  },
                  controller: otpController,
                  autoDisposeControllers: false,
                  cursorColor: const Color(0xFF00C4B4),
                  pinTheme: PinTheme(
                    activeFillColor: Colors.grey[100],
                    inactiveFillColor: Colors.grey[100],
                    selectedFillColor: const Color(0xFF00C4B4).withOpacity(0.1),
                    activeColor: const Color(0xFF00C4B4),
                    inactiveColor: Colors.black45,
                    selectedColor: const Color(0xFF00C4B4),
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(8),
                    fieldHeight: 50,
                    fieldWidth: 45,
                  ),
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
                    onPressed: isButtonEnabled && !isLoading ? verifyOTP : null,
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
                            'Verify OTP',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 400.ms),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: canResend ? resendOTP : null,
                  child: Text(
                    canResend ? 'Resend Code' : 'Resend in ${resendTimer}s',
                    style: TextStyle(
                      color: canResend
                          ? const Color(0xFF00C4B4)
                          : Colors.grey,
                    ),
                  ),
                ).animate().fadeIn(duration: 600.ms, delay: 500.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}