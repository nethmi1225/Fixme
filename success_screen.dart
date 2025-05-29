import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Verification Successful'),
        backgroundColor: const Color(0xFF00C4B4),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFF00C4B4),
              child: const Icon(Icons.check, size: 40, color: Colors.white),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(curve: Curves.easeOut),
            const SizedBox(height: 20),
            const Text(
              'Verification Successful',
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
              'Your phone number has been verified.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ).animate().fadeIn(duration: 600.ms, delay: 200.ms),
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
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  // Navigate back to ProfileScreen and indicate success
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/profile',
                    (route) => false, // Clear the stack
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(150, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Back to Profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 600.ms, delay: 300.ms),
          ],
        ),
      ),
    );
  }
}