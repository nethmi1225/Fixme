import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  _AdminPanelScreenState createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  List<Map<dynamic, dynamic>> pendingRequests = [];
  List<Map<dynamic, dynamic>> adminNotifications = [];
  String? errorMessage;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      pendingRequests = [];
      adminNotifications = [];
    });
    try {
      // Fetch pending service provider requests
      final userSnapshot = await FirebaseDatabase.instance
          .ref('users')
          .orderByChild('role')
          .equalTo('pending_service_provider')
          .get();

      if (userSnapshot.exists) {
        final data = userSnapshot.value as Map<dynamic, dynamic>;
        setState(() {
          pendingRequests = data.entries.map((entry) {
            final serviceProviderDetails = entry.value['serviceProviderDetails'];
            if (serviceProviderDetails == null) return null;
            final status = serviceProviderDetails['status']?.toString();
            if (status != 'pending') return null;

            return {
              'uid': entry.key,
              ...serviceProviderDetails as Map<dynamic, dynamic>,
              'firstName': entry.value['firstName'] ?? 'Unknown',
              'warnings': serviceProviderDetails['warnings'] ?? 0,
            };
          }).where((entry) => entry != null).cast<Map<dynamic, dynamic>>().toList();
        });
      }

      // Fetch admin notifications
      final notificationSnapshot = await FirebaseDatabase.instance
          .ref('admin_notifications')
          .orderByChild('status')
          .equalTo('pending')
          .get();

      if (notificationSnapshot.exists) {
        final notifications = notificationSnapshot.value as Map<dynamic, dynamic>;
        setState(() {
          adminNotifications = notifications.entries.map((entry) {
            return {
              'notificationId': entry.key,
              ...entry.value as Map<dynamic, dynamic>,
            };
          }).toList();
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to fetch data: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _approveRequest(String uid, String firstName) async {
    try {
      await FirebaseDatabase.instance.ref('users/$uid').update({
        'role': 'service_provider',
        'serviceProviderDetails/status': 'approved',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$firstName has been approved as a service provider')),
      );
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve request: $e')),
      );
    }
  }

  Future<void> _declineRequest(String uid, String firstName) async {
    try {
      await FirebaseDatabase.instance.ref('users/$uid').update({
        'serviceProviderDetails/status': 'declined',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$firstName\'s request has been declined')),
      );
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to decline request: $e')),
      );
    }
  }

  Future<void> _warnProvider(String uid, String firstName, int currentWarnings, String notificationId) async {
    try {
      final newWarnings = currentWarnings + 1;
      final warningsLeft = 3 - newWarnings; // Calculate remaining warnings
      await FirebaseDatabase.instance.ref('users/$uid/serviceProviderDetails').update({
        'warnings': newWarnings,
      });

      // Update notification status
      if (notificationId.isNotEmpty) {
        await FirebaseDatabase.instance.ref('admin_notifications/$notificationId').update({
          'status': 'resolved',
          'action': 'warned',
        });
      }

      // Notify provider with remaining warnings
      await FirebaseDatabase.instance.ref('notifications/$uid').push().set({
        'timestamp': DateTime.now().toIso8601String(),
        'message': warningsLeft > 0
            ? 'Warning: Amount mismatch detected. This is warning #$newWarnings. You have $warningsLeft warning(s) left before a ban.'
            : 'Warning: Amount mismatch detected. This is warning #$newWarnings. You will be banned next.',
        'user_id': uid,
        'type': 'Warning',
        'read': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Warning issued to $firstName. Warnings: $newWarnings')),
      );

      if (newWarnings >= 3) {
        await _banProvider(uid, firstName, notificationId, autoBan: true);
      } else {
        _fetchData();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to warn provider: $e')),
      );
    }
  }

  Future<void> _banProvider(String uid, String firstName, String notificationId, {bool autoBan = false}) async {
    try {
      await FirebaseDatabase.instance.ref('users/$uid').update({
        'serviceProviderDetails/status': 'banned',
        'serviceProviderDetails/warnings': 0,
      });

      // Update notification status
      if (notificationId.isNotEmpty) {
        await FirebaseDatabase.instance.ref('admin_notifications/$notificationId').update({
          'status': 'resolved',
          'action': 'banned',
        });
      }

      // Notify provider of ban
      await FirebaseDatabase.instance.ref('notifications/$uid').push().set({
        'timestamp': DateTime.now().toIso8601String(),
        'message': autoBan
            ? 'You have been banned due to 3 warnings for amount mismatch.'
            : 'You have been banned by the admin.',
        'user_id': uid,
        'type': 'Ban',
        'read': false,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$firstName has been banned')),
      );
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to ban provider: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00C4B4),
        elevation: 0,
        title: const Text(
          'Admin Panel',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () {
            // Navigate to the SignInScreen using the named route and clear the stack
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/sign-in',
              (Route<dynamic> route) => false,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                print('User signed out successfully');
                // Navigate to the SignInScreen using the named route and clear the stack
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/sign-in',
                  (Route<dynamic> route) => false,
                );
              } catch (e) {
                print('Error during logout: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to log out: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFE0F7F5)],
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C4B4)))
            : errorMessage != null
                ? Center(child: Text(errorMessage!, style: const TextStyle(fontFamily: 'Open Sans', color: Colors.red)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section for Admin Notifications (Mismatch Reports)
                        const Text(
                          'Mismatch Notifications',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF131010),
                          ),
                        ),
                        const SizedBox(height: 10),
                        adminNotifications.isEmpty
                            ? const Center(
                                child: Text(
                                  'No pending notifications',
                                  style: TextStyle(fontFamily: 'Open Sans', fontSize: 16),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: adminNotifications.length,
                                itemBuilder: (context, index) {
                                  final notification = adminNotifications[index];
                                  final providerId = notification['providerId'] as String;
                                  final providerName = notification['providerName'] as String;
                                  final notificationId = notification['notificationId'] as String;

                                  return FutureBuilder(
                                    future: FirebaseDatabase.instance.ref('users/$providerId/serviceProviderDetails').get(),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData || snapshot.hasError) {
                                        return const SizedBox.shrink();
                                      }
                                      final providerData = snapshot.data!.value as Map<dynamic, dynamic>? ?? {};
                                      final warnings = providerData['warnings'] as int? ?? 0;
                                      final status = providerData['status'] as String? ?? 'unknown';

                                      if (status == 'banned') {
                                        return const SizedBox.shrink();
                                      }

                                      return Container(
                                        margin: const EdgeInsets.symmetric(vertical: 10),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(16),
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFF8FAFC), Color(0xFFFFE0E0)],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.grey.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(18),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                '⚠️ Mismatch Report',
                                                style: TextStyle(
                                                  fontFamily: 'Montserrat',
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.red,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Provider: $providerName',
                                                style: const TextStyle(fontFamily: 'Open Sans', fontSize: 14, color: Color(0xFF131010)),
                                              ),
                                              Text(
                                                notification['message'] as String? ?? 'No message',
                                                style: const TextStyle(fontFamily: 'Open Sans', fontSize: 14, color: Color(0xFF131010)),
                                              ),
                                              Text(
                                                'Current Warnings: $warnings',
                                                style: const TextStyle(fontFamily: 'Open Sans', fontSize: 14, color: Colors.orange),
                                              ),
                                              const SizedBox(height: 16),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  ElevatedButton.icon(
                                                    onPressed: () => _warnProvider(providerId, providerName, warnings, notificationId),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.orange,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    ),
                                                    icon: const Icon(Icons.warning),
                                                    label: const Text('Warn'),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  ElevatedButton.icon(
                                                    onPressed: () => _banProvider(providerId, providerName, notificationId),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    ),
                                                    icon: const Icon(Icons.block),
                                                    label: const Text('Ban'),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                        const SizedBox(height: 20),

                        // Section for Pending Requests
                        const Text(
                          'Pending Requests',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF131010),
                          ),
                        ),
                        const SizedBox(height: 10),
                        pendingRequests.isEmpty
                            ? const Center(
                                child: Text(
                                  'No pending requests',
                                  style: TextStyle(fontFamily: 'Open Sans', fontSize: 16),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: pendingRequests.length,
                                itemBuilder: (context, index) {
                                  final request = pendingRequests[index];
                                  return Container(
                                    margin: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFF8FAFC), Color(0xFFE0F7F5)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.grey.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(18),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '👩 Name: ${request['firstName']}',
                                            style: const TextStyle(
                                              fontFamily: 'Montserrat',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Color(0xFF131010),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '🛠️ Service: ${request['serviceType'] ?? 'N/A'}',
                                            style: const TextStyle(fontFamily: 'Open Sans', fontSize: 14, color: Color(0xFF131010)),
                                          ),
                                          Text(
                                            '📆 Experience: ${request['experience']?.toString() ?? 'N/A'} years',
                                            style: const TextStyle(fontFamily: 'Open Sans', fontSize: 14, color: Color(0xFF131010)),
                                          ),
                                          Text(
                                            '📍 Location: ${request['location'] ?? 'N/A'}',
                                            style: const TextStyle(fontFamily: 'Open Sans', fontSize: 14, color: Color(0xFF131010)),
                                          ),
                                          Text(
                                            '📌 Working Areas: ${request['workingAreas']?.join(', ') ?? 'N/A'}',
                                            style: const TextStyle(fontFamily: 'Open Sans', fontSize: 14, color: Color(0xFF131010)),
                                          ),
                                          Text(
                                            '💰 Payment Type: ${request['paymentType'] ?? 'N/A'}',
                                            style: const TextStyle(fontFamily: 'Open Sans', fontSize: 14, color: Color(0xFF131010)),
                                          ),
                                          Text(
                                            '💵 Rate: ${request['rate']?.toString() ?? 'N/A'}',
                                            style: const TextStyle(fontFamily: 'Open Sans', fontSize: 14, color: Color(0xFF131010)),
                                          ),
                                          Text(
                                            '⚠️ Warnings: ${request['warnings']}',
                                            style: const TextStyle(fontFamily: 'Open Sans', fontSize: 14, color: Colors.orange),
                                          ),
                                          const SizedBox(height: 16),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: () => _approveRequest(request['uid'], request['firstName']),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.green,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                icon: const Icon(Icons.check),
                                                label: const Text('Approve'),
                                              ),
                                              const SizedBox(width: 12),
                                              ElevatedButton.icon(
                                                onPressed: () => _declineRequest(request['uid'], request['firstName']),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.redAccent,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                icon: const Icon(Icons.close),
                                                label: const Text('Decline'),
                                              ),
                                              const SizedBox(width: 12),
                                              ElevatedButton.icon(
                                                onPressed: () => _warnProvider(request['uid'], request['firstName'], request['warnings'], ''),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.orange,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                icon: const Icon(Icons.warning),
                                                label: const Text('Warn'),
                                              ),
                                              const SizedBox(width: 12),
                                              ElevatedButton.icon(
                                                onPressed: () => _banProvider(request['uid'], request['firstName'], ''),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                ),
                                                icon: const Icon(Icons.block),
                                                label: const Text('Ban'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
      ),
    );
  }
}