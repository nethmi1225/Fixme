import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:lottie/lottie.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'navigation_utils.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  _SignInScreenState createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveFcmToken(String uid) async {
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      print('Saving FCM token for user $uid: $token');
      await _database.child('users/$uid/fcmToken').set(token);
    } else {
      print('Failed to get FCM token for user $uid');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        return Scaffold(
          backgroundColor: const Color(0xFFFFFFFF),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'Login',
                      style: TextStyle(
                        fontFamily: 'londonbridgefontfamily',
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Lottie Animation
                  Center(
                    child: SizedBox(
                      width: 500,
                      height: 200,
                      child: Lottie.asset(
                        'assets/Sign_IN_new.json',
                        animate: true,
                        repeat: true,
                        frameRate: FrameRate(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Welcome Text with Poppins font
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hello There!',
                          style: TextStyle(
                            fontFamily: 'Antipasto',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text.rich(
                          TextSpan(
                            text: 'Welcome ',
                            style: const TextStyle(
                              fontFamily: 'Antipasto',
                              fontSize: 14,
                              color: Colors.black,
                            ),
                            children: [
                              const TextSpan(
                                text: '😊 ',
                                style: TextStyle(fontSize: 14),
                              ),
                              const TextSpan(
                                text: 'YOU’VE BEEN MISSED. PLEASE ENTER YOUR DATA TO LOG IN.',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 12,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Form Fields
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            labelText: 'Username/Phone No',
                            labelStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF24A8AF)),
                            ),
                            errorText: authViewModel.errorMessage,
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            labelText: 'Password',
                            labelStyle: const TextStyle(color: Colors.grey),
                            prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Colors.grey),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF24A8AF)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Forget password?',
                              style: TextStyle(
                                color: Color(0xFF131010),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        authViewModel.isLoading
                            ? const CircularProgressIndicator(color: Color(0xFF24A8AF))
                            : SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    String email = _emailController.text.trim();
                                    String password = _passwordController.text.trim();

                                    if (email.isEmpty || password.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please fill all fields')),
                                      );
                                      return;
                                    }
                                    if (!email.contains('@') && !RegExp(r'^\d+$').hasMatch(email)) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Please enter a valid email or phone number')),
                                      );
                                      return;
                                    }

                                    try {
                                      print('Attempting to sign in with: $email');
                                      await authViewModel.signIn(email, password);
                                      if (authViewModel.user != null) {
                                        print('Sign-in successful, user UID: ${FirebaseAuth.instance.currentUser!.uid}');
                                        // Save FCM token after sign-in
                                        await _saveFcmToken(FirebaseAuth.instance.currentUser!.uid);
                                        await navigateBasedOnRole(context, FirebaseAuth.instance.currentUser!);
                                      } else {
                                        print('Sign-in failed, user is null');
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(authViewModel.errorMessage ?? 'Sign-in failed. Please try again.')),
                                        );
                                      }
                                    } catch (e) {
                                      print('Error during sign-in: $e');
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('An error occurred: $e')),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF24A8AF),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  child: const Text(
                                    'Login',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 20),
                        Center(
                          child: GestureDetector(
                            onTap: () => Navigator.pushNamed(context, '/sign-up'),
                            child: const Text(
                              'Don’t have an account? Sign up',
                              style: TextStyle(
                                color: Color(0xFF131010),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}