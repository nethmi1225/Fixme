import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class CustomerProfileScreen extends StatefulWidget {
  final String customerId;
  final String bookingId;
  final String customerLocation;

  const CustomerProfileScreen({
    super.key,
    required this.customerId,
    required this.bookingId,
    required this.customerLocation,
  });

  @override
  CustomerProfileScreenState createState() => CustomerProfileScreenState();
}

class CustomerProfileScreenState extends State<CustomerProfileScreen>
    with SingleTickerProviderStateMixin {
  double? lat;
  double? long;
  String customerName = 'Unknown';
  String phoneNumber = 'Not set';
  String? profilePhotoBase64;
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _parseLocation();
    _fetchCustomerDetails();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _parseLocation() {
    try {
      final latLong = widget.customerLocation.split(',');
      lat = double.parse(latLong[0]);
      long = double.parse(latLong[1]);
    } catch (e) {
      lat = null;
      long = null;
    }
  }

  Future<void> _fetchCustomerDetails() async {
    setState(() {
      isLoading = true;
    });

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users/${widget.customerId}')
          .get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          customerName = data['firstName']?.toString() ?? 'Unknown';
          phoneNumber = data['phoneNumber']?.toString() ?? 'Not set';
          profilePhotoBase64 = data['profilePhoto']?.toString();
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching customer details: $e')),
      );
    }
  }

  Widget _buildProfileImage() {
    if (profilePhotoBase64 != null && profilePhotoBase64!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(profilePhotoBase64!);
        return CircleAvatar(
          radius: 30,
          backgroundColor: Colors.white,
          backgroundImage: MemoryImage(imageBytes),
        );
      } catch (e) {
        return _defaultAvatar();
      }
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return CircleAvatar(
      radius: 30,
      backgroundColor: const Color(0xFF00C4B4),
      child: Icon(
        Icons.person,
        size: 40,
        color: Colors.white,
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone call')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF00C4B4),
          title: const Text(
            'Customer Profile',
            style: TextStyle(
              fontFamily: 'londonbridgefontfamily',
              fontSize: 25,
              color: Colors.white,
            ),
          ),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00C4B4),
          ),
        ),
      );
    }

    if (lat == null || long == null || (lat == 0 && long == 0)) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFF00C4B4),
          title: const Text(
            'Customer Profile',
            style: TextStyle(
              fontFamily: 'londonbridgefontfamily',
              fontSize: 25,
              color: Colors.white,
            ),
          ),
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Invalid or unavailable location data',
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 16,
              color: Color(0xFF131010),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00C4B4),
        title: const Text(
          'Customer Profile',
          style: TextStyle(
            fontFamily: 'londonbridgefontfamily',
            fontSize: 25,
            color: Colors.white,
          ),
        ),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _makePhoneCall(phoneNumber),
        backgroundColor: const Color(0xFF00C4B4),
        child: const Icon(
          Icons.phone,
          color: Colors.white,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(lat!, long!),
                zoom: 14,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('customer_location'),
                  position: LatLng(lat!, long!),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                ),
              },
            ),
          ),
          FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF00C4B4),
                        Colors.white,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildProfileImage(),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Booking Details',
                                    style: TextStyle(
                                      fontFamily: 'Lato',
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF131010),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Booking ID: ${widget.bookingId}',
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 16,
                                      color: Color(0xFF131010),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFF00C4B4), thickness: 1),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              color: Color(0xFF00C4B4),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Name: $customerName',
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 16,
                                  color: Color(0xFF131010),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(
                              Icons.phone,
                              color: Color(0xFF00C4B4),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Phone: $phoneNumber',
                                style: const TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 16,
                                  color: Color(0xFF131010),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}