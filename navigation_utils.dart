// File: lib/features/auth/presentation/views/navigation_utils.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fixme_new/features/auth/presentation/views/AdminPanelScreen.dart';

Future<void> navigateBasedOnRole(BuildContext context, User user) async {
  try {
    print('Navigating based on role for UID: ${user.uid}');
    final snapshot = await FirebaseDatabase.instance
        .ref('users/${user.uid}')
        .get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      final role = data['role']?.toString() ?? 'customer';
      print('User role: $role');

      // Check service provider status if role is service_provider
      if (role == 'service_provider') {
        final serviceProviderDetails = data['serviceProviderDetails'] as Map<dynamic, dynamic>? ?? {};
        final status = serviceProviderDetails['status']?.toString() ?? 'unknown';
        if (status == 'banned') {
          print('User is banned, showing ban message');
          showDialog(
            context: context,
            barrierDismissible: false, // User must press OK to dismiss
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Account Banned'),
                content: const Text('You were banned due to cheat/unusual activities.'),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Dismiss the dialog
                      // Optionally sign out the user to ensure they can't retry
                      FirebaseAuth.instance.signOut();
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
          return; // Exit the function to prevent further navigation
        }
      }

      if (role == 'admin') {
        print('Navigating to AdminPanelScreen');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminPanelScreen()),
        );
      } else {
        // Direct to the home screen for non-admin users
        print('Navigating to HomeScreen (via /home route)');
        Navigator.pushReplacementNamed(context, '/home');
      }
    } else {
      print('User data not found, navigating to SignUpScreen');
      Navigator.pushReplacementNamed(context, '/sign-up');
    }
  } catch (e) {
    print('Error fetching user data for navigation: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error fetching user data: $e')),
    );
    Navigator.pushReplacementNamed(context, '/sign-in');
  }
}