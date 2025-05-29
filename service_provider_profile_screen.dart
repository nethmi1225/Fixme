import 'package:fixme_new/features/auth/data/models/ChatUserModel.dart';
import 'package:fixme_new/features/auth/data/models/service_provider_details.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fixme_new/features/auth/presentation/views/ChatPage.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:convert';
import 'dart:math';

class ServiceProviderProfileScreen extends StatefulWidget {
  final String category;
  final String providerId;

  const ServiceProviderProfileScreen({
    super.key,
    required this.category,
    required this.providerId,
  });

  @override
  _ServiceProviderProfileScreenState createState() => _ServiceProviderProfileScreenState();
}

class _ServiceProviderProfileScreenState extends State<ServiceProviderProfileScreen>
    with SingleTickerProviderStateMixin {
  ServiceProviderDetails? providerDetails;
  String? providerName;
  String? profilePhoto;
  String? paymentType;
  List<Map<String, dynamic>> reviews = [];
  bool hasBooked = false;
  double? distanceFromUser;
  int jobsDone = 0;
  bool isPhoneVerified = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Animation<double>? _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
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
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    _fetchProviderDetails();
    _fetchJobsDone();
    _calculateDistance();
    _logViewInteraction();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _logViewInteraction() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user is currently logged in');
        return;
      }
      final userId = user.uid;

      final ref = FirebaseDatabase.instance
          .ref('interactions/$userId/${widget.providerId}/view');
      await ref.set({
        'value': 0,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error logging view interaction: $e');
    }
  }

  Future<void> _logBookingInteraction() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No user is currently logged in');
        return;
      }
      final userId = user.uid;

      final ref = FirebaseDatabase.instance
          .ref('interactions/$userId/${widget.providerId}/booking');
      await ref.set({
        'value': 1,
        'timestamp': DateTime.now().toIso8601String(),
      });

      setState(() {
        hasBooked = true;
      });

      await _saveBookingDetails(userId);
      await _sendNotificationToProvider(userId);
    } catch (e) {
      print('Error logging booking interaction: $e');
    }
  }

  Future<void> _saveBookingDetails(String userId) async {
    try {
      final customerSnapshot = await FirebaseDatabase.instance
          .ref('users/$userId')
          .get();
      String customerName = 'Unknown';

      if (customerSnapshot.exists) {
        final customerData = customerSnapshot.value as Map<dynamic, dynamic>;
        customerName = customerData['firstName'] as String? ?? 'Unknown';
      }

      final bookingRef = FirebaseDatabase.instance.ref('bookings/$userId').push();
      await bookingRef.set({
        'provider_id': widget.providerId,
        'category': widget.category,
        'customer_name': customerName,
        'status': 'Pending',
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('Error saving booking details: $e');
    }
  }

  Future<void> _sendNotificationToProvider(String userId) async {
    try {
      final customerSnapshot = await FirebaseDatabase.instance
          .ref('users/$userId')
          .get();
      String customerName = 'Unknown';
      String customerLocation = 'Unknown';
      String coordinates = '0,0';

      if (customerSnapshot.exists) {
        final customerData = customerSnapshot.value as Map<dynamic, dynamic>;
        customerName = customerData['firstName'] as String? ?? 'Unknown';
        customerLocation = customerData['hometown'] as String? ?? 'Unknown';

        final latitude = customerData['latitude'] as num?;
        final longitude = customerData['longitude'] as num?;
        if (latitude != null && longitude != null) {
          coordinates = '$latitude,$longitude';
        } else {
          try {
            List<Location> locations = await locationFromAddress("$customerLocation, Sri Lanka");
            if (locations.isNotEmpty) {
              final location = locations.first;
              coordinates = '${location.latitude},${location.longitude}';
              await FirebaseDatabase.instance.ref('users/$userId').update({
                'latitude': location.latitude,
                'longitude': location.longitude,
              });
            }
          } catch (e) {
            print('Error geocoding $customerLocation: $e');
          }
        }
      }

      final notificationRef = FirebaseDatabase.instance
          .ref('notifications/${widget.providerId}')
          .push();
      await notificationRef.set({
        'user_id': userId,
        'category': widget.category,
        'status': 'Pending',
        'timestamp': DateTime.now().toIso8601String(),
        'customer_name': customerName,
        'customer_location': customerLocation,
        'coordinates': coordinates,
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  Future<void> _calculateDistance() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userSnapshot = await FirebaseDatabase.instance
          .ref('users/${user.uid}')
          .get();
      final providerSnapshot = await FirebaseDatabase.instance
          .ref('users/${widget.providerId}')
          .get();

      if (!userSnapshot.exists || !providerSnapshot.exists) return;

      final userData = userSnapshot.value as Map<dynamic, dynamic>;
      final providerData = providerSnapshot.value as Map<dynamic, dynamic>;

      String userLocation = userData['hometown'] as String? ?? 'Unknown';
      String providerLocation = providerData['hometown'] as String? ?? 'Unknown';

      double? userLat = userData['latitude'] as double?;
      double? userLon = userData['longitude'] as double?;
      double? providerLat = providerData['latitude'] as double?;
      double? providerLon = providerData['longitude'] as double?;

      if (userLat == null || userLon == null) {
        List<Location> userLocations = await locationFromAddress("$userLocation, Sri Lanka");
        if (userLocations.isNotEmpty) {
          userLat = userLocations.first.latitude;
          userLon = userLocations.first.longitude;
          await FirebaseDatabase.instance.ref('users/${user.uid}').update({
            'latitude': userLat,
            'longitude': userLon,
          });
        }
      }

      if (providerLat == null || providerLon == null) {
        List<Location> providerLocations = await locationFromAddress("$providerLocation, Sri Lanka");
        if (providerLocations.isNotEmpty) {
          providerLat = providerLocations.first.latitude;
          providerLon = providerLocations.first.longitude;
          await FirebaseDatabase.instance.ref('users/${widget.providerId}').update({
            'latitude': providerLat,
            'longitude': providerLon,
          });
        }
      }

      if (userLat != null && userLon != null && providerLat != null && providerLon != null) {
        const double earthRadius = 6371; // Radius of the earth in km
        final double dLat = _degreesToRadians(providerLat - userLat);
        final double dLon = _degreesToRadians(providerLon - userLon);
        final double a = sin(dLat / 2) * sin(dLat / 2) +
            cos(_degreesToRadians(userLat)) * cos(_degreesToRadians(providerLat)) *
                sin(dLon / 2) * sin(dLon / 2);
        final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
        final double distance = earthRadius * c; // Distance in km

        setState(() {
          distanceFromUser = distance;
        });
      }
    } catch (e) {
      print('Error calculating distance: $e');
    }
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<void> _fetchJobsDone() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not authenticated. Cannot fetch jobs done.');
        return;
      }
      final snapshot = await FirebaseDatabase.instance
          .ref('billing')
          .orderByChild('provider_id')
          .equalTo(widget.providerId)
          .get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        print('Billing data for providerId ${widget.providerId}: $data');
        int paidJobs = 0;
        data.forEach((key, value) {
          print('Billing entry $key: $value');
          if (value['status'] == 'paid') {
            paidJobs++;
          }
        });
        setState(() {
          jobsDone = paidJobs;
        });
      } else {
        print('No billing data found for providerId: ${widget.providerId}');
      }
    } catch (e) {
      print('Error fetching jobs done: $e');
    }
  }

  Future<void> _fetchProviderDetails() async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users')
          .child(widget.providerId)
          .get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        Map<String, dynamic> serviceProviderDetails = {};

        // Check if isPhoneVerified field exists and set the state
        bool phoneVerified = data.containsKey('isPhoneVerified') && data['isPhoneVerified'] == true;

        if (data.containsKey('serviceProviderDetails')) {
          serviceProviderDetails = Map<String, dynamic>.from(data['serviceProviderDetails']);
          print('Raw serviceProviderDetails: $serviceProviderDetails');

          if (serviceProviderDetails.containsKey('rate')) {
            serviceProviderDetails['hourlyRate'] = serviceProviderDetails['rate'];
            print('Mapped rate to hourlyRate: ${serviceProviderDetails['hourlyRate']}');
          } else {
            print('Rate not found in serviceProviderDetails: $serviceProviderDetails');
            serviceProviderDetails['hourlyRate'] = 0;
          }

          serviceProviderDetails['uid'] = widget.providerId;

          String rawPaymentType = serviceProviderDetails['payment_type'] as String? ??
              serviceProviderDetails['paymentType'] as String? ?? 'fixedrate';
          String category = serviceProviderDetails['category'] as String? ?? widget.category;
          String displayPaymentType;

          String displayCategory;
          switch (category.toLowerCase()) {
            case 'painter':
              displayCategory = 'Painting';
              break;
            case 'electrician':
              displayCategory = 'Electrical Job';
              break;
            case 'plumber':
              displayCategory = 'Plumbing Job';
              break;
            case 'mason':
            case 'meson':
              displayCategory = 'Masonry Job';
              break;
            default:
              displayCategory = 'Job';
          }

          switch (rawPaymentType.toLowerCase()) {
            case 'hourly':
              displayPaymentType = 'Per Hour';
              break;
            case 'squarefeet':
              displayPaymentType = 'Per Sq Ft';
              break;
            case 'fixedrate':
              displayPaymentType = 'Per Daily Rate';
              break;
            default:
              displayPaymentType = 'Per $displayCategory';
          }

          final providerDetails = ServiceProviderDetails.fromMap(serviceProviderDetails);

          setState(() {
            this.providerDetails = providerDetails;
            providerName = data['firstName'] as String? ?? 'Unknown';
            profilePhoto = data['profilePhoto']?.toString();
            paymentType = displayPaymentType;
            isPhoneVerified = phoneVerified;
            reviews = providerDetails.reviews?.entries.map((entry) {
              return {
                'user': entry.value['user'] as String? ?? 'Anonymous',
                'comment': entry.value['comment'] as String? ?? '',
                'rating': entry.value['rating'] as num? ?? 0,
              };
            }).toList() ?? [];
          });

          print('Final providerDetails: hourlyRate=${providerDetails.hourlyRate}, paymentType=$paymentType, bio=${providerDetails.bio}');
        } else {
          print('No serviceProviderDetails found for this provider');
          setState(() {
            providerName = data['firstName'] as String? ?? 'Unknown';
            profilePhoto = data['profilePhoto']?.toString();
            isPhoneVerified = phoneVerified;
          });
        }
      } else {
        print('Provider data does not exist');
        setState(() {
          providerName = 'Unknown';
        });
      }
    } catch (e) {
      print('Error fetching provider details: $e');
      setState(() {
        providerName = 'Unknown';
      });
    }
  }

  double _calculateAverageRating() {
    if (reviews.isEmpty) return 0.0;
    final totalRating = reviews.fold<double>(0.0, (sum, review) => sum + (review['rating'] as num).toDouble());
    return totalRating / reviews.length;
  }

  bool _isTopProvider() {
    final avgRating = _calculateAverageRating();
    return avgRating >= 4.5 || jobsDone >= 50;
  }

  Widget _buildProfileImage() {
    final isTopProvider = _isTopProvider();

    if (profilePhoto != null && profilePhoto!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(profilePhoto!);
        return Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.white,
              backgroundImage: MemoryImage(imageBytes),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
              ),
            ),
            if (isTopProvider)
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomLeft: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    'Top Provider',
                    style: TextStyle(
                      color: Color(0xFF00C4B4),
                      fontSize: 11,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (isPhoneVerified)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green[600],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      topRight: Radius.circular(16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
          ],
        );
      } catch (e) {
        print('Error loading profile photo: $e');
        return _defaultAvatarWithLabels();
      }
    }
    return _defaultAvatarWithLabels();
  }

  Widget _defaultAvatarWithLabels() {
    final isTopProvider = _isTopProvider();

    return Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: Colors.white,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(
              Icons.person,
              size: 50,
              color: Color(0xFF00C4B4),
            ),
          ),
        ),
        if (isTopProvider)
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomLeft: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Top Provider',
                style: TextStyle(
                  color: Color(0xFF00C4B4),
                  fontSize: 11,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        if (isPhoneVerified)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.green[600],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  topRight: Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final avgRating = _calculateAverageRating();
    final isTopProvider = _isTopProvider();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: providerName == null
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C4B4)))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 250.0,
                  floating: false,
                  pinned: true,
                  backgroundColor: const Color(0xFF00C4B4),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  title: const Text(
                    'Provider Profile',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  titleSpacing: 0,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF00C4B4),
                            Color(0xFF4DD0E1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
                          final double deltaExtent = settings!.maxExtent - settings.minExtent;
                          final double t = (1.0 - (settings.currentExtent - settings.minExtent) / deltaExtent).clamp(0.0, 1.0);
                          final double opacity = 1.0 - t;

                          return Padding(
                            padding: const EdgeInsets.only(top: 100.0, bottom: 16.0),
                            child: Center(
                              child: Opacity(
                                opacity: opacity,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        _buildProfileImage(),
                                        if (isTopProvider)
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: const BorderRadius.only(
                                                  topRight: Radius.circular(8),
                                                  bottomLeft: Radius.circular(16),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withOpacity(0.1),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Text(
                                                'Top Provider',
                                                style: TextStyle(
                                                  color: Color(0xFF00C4B4),
                                                  fontSize: 11,
                                                  fontFamily: 'Poppins',
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Flexible(
                                      child: Text(
                                        providerName!.toUpperCase(),
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Flexible(
                                      child: Text(
                                        widget.category.toUpperCase(),
                                        style: const TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 14,
                                          color: Colors.white70,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.monetization_on,
                                value: paymentType ?? 'Fixed Rate',
                                label: 'Payment Type',
                                gradientColors: const [
                                  Color(0xFF00C4B4),
                                  Color(0xFF4DD0E1),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildStatCard(
                                icon: Icons.location_on,
                                value: '${distanceFromUser != null ? distanceFromUser!.toStringAsFixed(1) : 'N/A'} km',
                                label: 'Distance from You',
                                gradientColors: const [
                                  Color(0xFF00C4B4),
                                  Color(0xFF4DD0E1),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'About Provider',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF131010),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    providerDetails?.bio ?? 'No bio available',
                                    style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 14,
                                      color: Colors.grey,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Reviews',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF131010),
                              ),
                            ),
                            Text(
                              '${avgRating.toStringAsFixed(1)}/5 (${reviews.length} reviews)',
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                fontSize: 14,
                                color: Color(0xFF131010),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        reviews.isEmpty
                            ? const Text(
                                'No reviews yet',
                                style: TextStyle(
                                  fontFamily: 'Roboto',
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: reviews.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: Card(
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const CircleAvatar(
                                              radius: 18,
                                              backgroundColor: Color(0xFF00C4B4),
                                              child: Icon(
                                                Icons.person,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    reviews[index]['user'],
                                                    style: const TextStyle(
                                                      fontFamily: 'Roboto',
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF131010),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '"${reviews[index]['comment']}"',
                                                    style: const TextStyle(
                                                      fontFamily: 'Roboto',
                                                      fontSize: 13,
                                                      color: Colors.grey,
                                                      height: 1.4,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: List.generate(5, (starIndex) {
                                                      return Icon(
                                                        starIndex < reviews[index]['rating']
                                                            ? Icons.star
                                                            : Icons.star_border,
                                                        color: Colors.amber,
                                                        size: 16,
                                                      );
                                                    }),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              flex: 2,
                              child: GestureDetector(
                                onTapDown: (_) => _animationController.reverse(),
                                onTapUp: (_) {
                                  _animationController.forward();
                                  if (!hasBooked) {
                                    _logBookingInteraction();
                                  }
                                },
                                onTapCancel: () => _animationController.forward(),
                                child: ScaleTransition(
                                  scale: _buttonScaleAnimation!,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF00C4B4),
                                          Color(0xFF4DD0E1),
                                        ],
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
                                      onPressed: hasBooked
                                          ? null
                                          : () {
                                              _logBookingInteraction();
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                        minimumSize: const Size(0, 48),
                                      ),
                                      child: Text(
                                        hasBooked ? 'BOOKED' : 'HIRE NOW',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00C4B4),
                                    Color(0xFF4DD0E1),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () async {
                                    final user = FirebaseAuth.instance.currentUser;
                                    if (user == null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please log in to chat'),
                                        ),
                                      );
                                      Navigator.pushNamed(context, '/sign-in');
                                      return;
                                    }

                                    try {
                                      final snapshot = await FirebaseDatabase.instance
                                          .ref('users/${widget.providerId}')
                                          .get();
                                      if (snapshot.exists) {
                                        final userData = snapshot.value as Map<dynamic, dynamic>;
                                        userData['uid'] = widget.providerId;
                                        final receiver = ChatUserModel.fromMap(
                                            Map<String, dynamic>.from(userData));
                                        final senderSnapshot = await FirebaseDatabase.instance
                                            .ref('users/${user.uid}')
                                            .get();
                                        String senderName = 'Unknown';
                                        if (senderSnapshot.exists) {
                                          final senderData = senderSnapshot.value as Map<dynamic, dynamic>;
                                          senderName = senderData['firstName'] as String? ?? 'Unknown';
                                        }
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => ChatPage(
                                              receiver: receiver,
                                              receiverUid: widget.providerId,
                                              senderName: senderName,
                                            ),
                                          ),
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Provider user data not found'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: $e'),
                                        ),
                                      );
                                    }
                                  },
                                  child: const SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Icon(
                                      Icons.message,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 0),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 11,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, int selectedIndex) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xFF00C4B4),
      items: const <BottomNavigationBarItem>[
        BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.book), label: 'Booking'),
        BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
      currentIndex: selectedIndex,
      selectedItemColor: Colors.white,
      unselectedItemColor: Colors.white70,
      selectedFontSize: 12,
      unselectedFontSize: 10,
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