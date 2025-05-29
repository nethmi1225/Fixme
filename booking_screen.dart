import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:fixme_new/features/auth/presentation/views/payment_method_screen.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  _BookingScreenState createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> bookings = [];
  int ongoingCount = 0;
  int completedCount = 0;
  int cancelledCount = 0;
  TabController? _tabController;
  int _selectedTabIndex = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchBookings();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchBookings() async {
    setState(() {
      isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user is currently logged in');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to view bookings')),
        );
        setState(() {
          isLoading = false;
        });
        return;
      }
      final userId = user.uid;

      final snapshot = await FirebaseDatabase.instance.ref('bookings/$userId').get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        List<Map<String, dynamic>> tempBookings = [];

        for (var entry in data.entries) {
          final bookingData = entry.value as Map<dynamic, dynamic>;
          final providerId = bookingData['provider_id'] as String;

          // Fetch provider details
          final providerSnapshot =
              await FirebaseDatabase.instance.ref('users/$providerId').get();
          String providerName = 'Unknown';
          String providerCategory = bookingData['category'] as String;
          if (providerSnapshot.exists) {
            final providerData = providerSnapshot.value as Map<dynamic, dynamic>;
            providerName = providerData['firstName'] as String? ?? 'Unknown';
            if (providerData['role'] == 'service_provider' &&
                providerData['serviceProviderDetails'] != null) {
              final serviceProviderDetails =
                  providerData['serviceProviderDetails'] as Map<dynamic, dynamic>;
              providerCategory =
                  serviceProviderDetails['category'] as String? ?? providerCategory;
            }
          }

          // Fetch billing details to get the total amount, billing ID, and status
          double totalAmount = 0.0;
          String? billingId;
          String billingStatus = 'pending'; // Default status
          final billingSnapshot = await FirebaseDatabase.instance
              .ref('billing')
              .orderByChild('booking_id')
              .equalTo(entry.key)
              .get();
          if (billingSnapshot.exists) {
            final billingData = billingSnapshot.value as Map<dynamic, dynamic>;
            final billingEntry = billingData.entries.first;
            billingId = billingEntry.key;
            // Safely handle total_amount
            final rawTotalAmount = billingEntry.value['total_amount'];
            if (rawTotalAmount != null) {
              if (rawTotalAmount is num) {
                totalAmount = rawTotalAmount.toDouble();
              } else if (rawTotalAmount is String) {
                totalAmount = double.tryParse(rawTotalAmount) ?? 0.0;
              }
            }
            // Get billing status
            billingStatus = billingEntry.value['status'] as String? ?? 'pending';
          }

          tempBookings.add({
            'booking_id': entry.key,
            'provider_id': providerId,
            'provider_name': providerName,
            'category': providerCategory,
            'status': bookingData['status'] as String,
            'timestamp': bookingData['timestamp'] as String,
            'total_amount': totalAmount,
            'billing_id': billingId,
            'billing_status': billingStatus,
          });
        }

        setState(() {
          bookings = tempBookings;
          ongoingCount =
              bookings.where((b) => b['status'] == 'Pending' || b['status'] == 'Accepted').length;
          completedCount = bookings.where((b) => b['status'] == 'Completed').length;
          cancelledCount = bookings.where((b) => b['status'] == 'Declined').length;
          isLoading = false;
        });
      } else {
        print('No bookings found for user $userId');
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching bookings: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching bookings: $e')),
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00C4B4),
        elevation: 0,
        title: const Text(
          'My Bookings',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: 25,
            color: Colors.white,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20.0),
            decoration: BoxDecoration(
              color: Colors.white,
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
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              indicator: BoxDecoration(
                color: const Color(0xFF00C4B4),
                borderRadius: BorderRadius.circular(12),
              ),
              labelStyle: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.bold,
                fontSize: 14, // Reduced font size to fit labels
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 14, // Reduced font size to fit labels
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 8.0), // Added padding for better spacing
              indicatorPadding: const EdgeInsets.symmetric(horizontal: 4.0), // Adjusted indicator padding
              onTap: (index) {
                setState(() {
                  _selectedTabIndex = index;
                });
              },
              tabs: [
                Tab(text: 'Ongoing ($ongoingCount)'),
                Tab(text: 'Completed ($completedCount)'),
                Tab(text: 'Cancelled ($cancelledCount)'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchBookings,
              color: const Color(0xFF00C4B4),
              child: isLoading
                  ? Column(
                      children: List.generate(
                        3,
                        (index) => Padding(
                          padding: const EdgeInsets.only(bottom: 16, left: 20, right: 20),
                          child: Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    )
                  : bookings.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'No bookings available',
                                style: TextStyle(
                                  fontFamily: 'Open Sans',
                                  fontSize: 16,
                                  color: Color(0xFF131010),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/home');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00C4B4),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: const Text(
                                  'Book a Service Now',
                                  style: TextStyle(
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildBookingList(
                                (booking) => booking['status'] == 'Pending' || booking['status'] == 'Accepted'),
                            _buildBookingList((booking) => booking['status'] == 'Completed'),
                            _buildBookingList((booking) => booking['status'] == 'Declined'),
                          ],
                        ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 1),
    );
  }

  Widget _buildBookingList(bool Function(Map<String, dynamic>) filter) {
    final filteredBookings = bookings.where(filter).toList();
    if (filteredBookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No bookings in this category',
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 16,
                color: Color(0xFF131010),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/home');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C4B4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'Book a Service Now',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      itemCount: filteredBookings.length,
      itemBuilder: (context, index) {
        final booking = filteredBookings[index];
        return _buildBookingCard(
          booking['provider_name'],
          booking['category'],
          booking['status'],
          booking['timestamp'],
          booking['booking_id'],
          booking['provider_id'],
          booking['total_amount'],
          booking['billing_id'],
        );
      },
    );
  }

  Widget _buildBookingCard(
      String providerName,
      String service,
      String status,
      String timestamp,
      String bookingId,
      String providerId,
      double totalAmount,
      String? billingId) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFF00C4B4),
              child: Icon(
                status == 'Completed'
                    ? Icons.check_circle
                    : status == 'Declined'
                        ? Icons.cancel
                        : Icons.hourglass_empty,
                size: 30,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$providerName ($service)',
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Color(0xFF131010),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Status: ',
                        style: TextStyle(
                          fontFamily: 'Open Sans',
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        status,
                        style: TextStyle(
                          fontFamily: 'Open Sans',
                          color: status == 'Pending'
                              ? Colors.orange
                              : status == 'Accepted'
                                  ? Colors.blue
                                  : status == 'Completed'
                                      ? Colors.green
                                      : Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Booked on: $timestamp',
                    style: const TextStyle(
                      fontFamily: 'Open Sans',
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            if (status == 'Completed' && billingId != null)
              Builder(
                builder: (context) {
                  final booking = bookings.firstWhere(
                    (b) => b['booking_id'] == bookingId,
                    orElse: () => {'billing_status': 'pending'},
                  );
                  final billingStatus = booking['billing_status'] as String;
                  if (billingStatus == 'paid') {
                    return ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        'Paid',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    );
                  } else {
                    return ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                PaymentMethodScreen(
                              bookingId: bookingId,
                              providerId: providerId,
                              providerName: providerName,
                              category: service,
                              totalAmount: totalAmount,
                              billingId: billingId,
                            ),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        ).then((result) {
                          if (result == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Payment successful!')),
                            );
                          }
                          _fetchBookings();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C4B4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      child: const Text(
                        'Pay',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    );
                  }
                },
              )
            else if (status == 'Pending')
              const Text(
                'Pending',
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              )
            else if (status == 'Accepted')
              const Text(
                'Accepted',
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              )
            else if (status == 'Declined')
              const Text(
                'Declined',
                style: TextStyle(
                  fontFamily: 'Open Sans',
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, int selectedIndex) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      elevation: 8,
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
          tooltip: 'Go to Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.book),
          label: 'Booking',
          tooltip: 'View Bookings',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.chat),
          label: 'Chat',
          tooltip: 'Open Chat',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
          tooltip: 'View Profile',
        ),
      ],
      currentIndex: selectedIndex,
      selectedItemColor: const Color(0xFF00C4B4),
      unselectedItemColor: Colors.grey,
      onTap: (index) {
        switch (index) {
          case 0:
            Navigator.pushReplacementNamed(context, '/home');
            break;
          case 1:
            Navigator.pushReplacementNamed(context, '/booking');
            break;
          case 2:
            Navigator.pushReplacementNamed(context, '/chat');
            break;
          case 3:
            Navigator.pushReplacementNamed(context, '/profile');
            break;
        }
      },
    );
  }
}