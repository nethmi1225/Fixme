import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fixme_new/features/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:fixme_new/features/auth/presentation/views/category_screen.dart';
import 'api_service.dart';
import 'dart:convert'; // For base64 decoding

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String firstName = 'User';
  String? profilePhotoBase64; // To store the user's profile photo
  int _selectedIndex = 0;
  String featuredImageUrl = 'https://i.imgur.com/8z5K7.jpg';
  final List<Map<String, dynamic>> categories = [
    {'title': 'Plumbing', 'icon': Icons.plumbing},
    {'title': 'Electrical', 'icon': Icons.electric_bolt},
    {'title': 'Cleaning', 'icon': Icons.cleaning_services},
    {'title': 'Mechanic', 'icon': Icons.build},
    {'title': 'A/C Repair', 'icon': Icons.ac_unit},
    {'title': 'Painter', 'icon': Icons.brush},
    {'title': 'Meson', 'icon': Icons.construction},
    {'title': 'Caregiver', 'icon': Icons.local_hospital},
    {'title': 'Home appliance repairing', 'icon': Icons.kitchen},
  ];
  List<Map<String, dynamic>> recommendedProviders = [];
  String? lastSearchedServiceType;
  bool isLoadingRecommendations = false;
  String? recommendationError;

  @override
  void initState() {
    super.initState();
    _fetchFirstName();
    _fetchFeaturedImage();
    _fetchRecommendations();
  }

  Future<void> _fetchFirstName() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        final snapshot = await FirebaseDatabase.instance
            .ref('users/${firebaseUser.uid}')
            .get();
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          setState(() {
            firstName = data['firstName']?.toString() ?? 'User';
            profilePhotoBase64 = data['profilePhoto']?.toString();
          });
        }
      } catch (e) {
        print('Error fetching user details: $e');
      }
    }
  }

  Future<void> _fetchFeaturedImage() async {
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('featured_image')
          .get();
      if (snapshot.exists) {
        setState(() {
          featuredImageUrl = snapshot.value.toString();
          print('Featured image URL: $featuredImageUrl');
        });
      } else {
        print('Featured image not found in database, using default URL');
        setState(() {
          featuredImageUrl = 'https://i.imgur.com/8z5K7.jpg';
        });
      }
    } catch (e) {
      print('Error fetching featured image: $e');
      setState(() {
        featuredImageUrl = 'https://i.imgur.com/8z5K7.jpg';
      });
    }
  }

  Future<void> _fetchRecommendations() async {
    setState(() {
      isLoadingRecommendations = true;
      recommendationError = null;
    });

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      setState(() {
        isLoadingRecommendations = false;
        recommendationError = 'Please log in to see recommendations';
      });
      return;
    }

    try {
      final apiService = ApiService();
      final recommendations = await apiService.getRecommendations(
        userId: firebaseUser.uid,
        category: lastSearchedServiceType,
        topN: 3,
      );

      setState(() {
        recommendedProviders = recommendations.map((provider) {
          return {
            'name': provider['name'],
            'service_type': provider['service_type'],
            'score': (provider['score'] as num?)?.toDouble() ?? 0.0,
            'location': provider['location'],
          };
        }).toList();
        isLoadingRecommendations = false;
      });
    } catch (e) {
      setState(() {
        isLoadingRecommendations = false;
        recommendationError = e.toString();
      });
      print('Error fetching recommendations: $e');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
  }

  // Build the profile image widget
  Widget _buildProfileImage() {
    if (profilePhotoBase64 != null && profilePhotoBase64!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(profilePhotoBase64!);
        return CircleAvatar(
          radius: 24,
          backgroundColor: Colors.white,
          backgroundImage: MemoryImage(imageBytes),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00C4B4), width: 2),
            ),
          ),
        );
      } catch (e) {
        print('Error decoding image: $e');
        return _defaultAvatar();
      }
    }
    return _defaultAvatar();
  }

  // Default avatar if no profile photo is available
  Widget _defaultAvatar() {
    return CircleAvatar(
      radius: 24,
      backgroundColor: Colors.white,
      foregroundColor: Colors.transparent,
      foregroundImage: null,
      child: Icon(
        Icons.person,
        size: 28,
        color: const Color(0xFF00C4B4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            bottomNavigationBarTheme: BottomNavigationBarThemeData(
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF00C4B4),
              unselectedItemColor: Colors.grey[400],
              elevation: 12,
              selectedIconTheme: const IconThemeData(size: 28),
              unselectedIconTheme: const IconThemeData(size: 24),
              selectedLabelStyle: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontFamily: 'Montserrat',
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
            ),
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF00C4B4),
                      Color(0xFF00A1A7),
                    ],
                  ),
                ),
              ),
              title: const Text(
                'FixMe',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              actions: [
                IconButton(
                  icon: Stack(
                    children: [
                      const Icon(
                        Icons.notifications,
                        color: Colors.white,
                        size: 28,
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: const Text(
                            '3',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {
                    Navigator.pushNamed(context, '/notification');
                  },
                ),
              ],
            ),
            body: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Section
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
                    color: Colors.white, // Changed to solid white, removing gradient
                    child: Row(
                      children: [
                        _buildProfileImage(),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Welcome $firstName',
                            style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF131010),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(15),
                      shadowColor: Colors.black12,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: lastSearchedServiceType != null
                              ? 'Last Search: $lastSearchedServiceType'
                              : 'Find a Plumber, Electrician, etc.',
                          hintStyle: TextStyle(
                            fontFamily: 'Open Sans',
                            color: Colors.grey[500],
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: const Color(0xFF00C4B4),
                            size: 24,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Color(0xFF00C4B4),
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
                        ),
                        style: const TextStyle(
                          color: Color(0xFF131010),
                          fontSize: 16,
                          fontFamily: 'Open Sans',
                          fontWeight: FontWeight.w500,
                        ),
                        onSubmitted: (value) {
                          if (categories.any((category) =>
                              category['title'].toLowerCase() == value.toLowerCase())) {
                            setState(() {
                              lastSearchedServiceType = value;
                            });
                            _fetchRecommendations();
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    CategoryScreen(category: value),
                                transitionsBuilder:
                                    (context, animation, secondaryAnimation, child) {
                                  return FadeTransition(opacity: animation, child: child);
                                },
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Categories Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Categories',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                            color: Color(0xFF131010),
                            letterSpacing: 0.5,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Navigate to all categories
                          },
                          child: const Text(
                            'See All',
                            style: TextStyle(
                              fontFamily: 'Open Sans',
                              fontSize: 14,
                              color: Color(0xFF00C4B4),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: categories.length,
                      itemBuilder: (context, index) {
                        final category = categories[index];
                        return CategoryCard(
                          title: category['title'],
                          icon: category['icon'],
                          onTap: () {
                            setState(() {
                              lastSearchedServiceType = category['title'];
                            });
                            _fetchRecommendations();
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (context, animation, secondaryAnimation) =>
                                    CategoryScreen(category: category['title']),
                                transitionsBuilder:
                                    (context, animation, secondaryAnimation, child) {
                                  return FadeTransition(opacity: animation, child: child);
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Recommendations Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Recommendations',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                            color: Color(0xFF131010),
                            letterSpacing: 0.5,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Navigate to all recommendations
                          },
                          child: const Text(
                            'See All',
                            style: TextStyle(
                              fontFamily: 'Open Sans',
                              fontSize: 14,
                              color: Color(0xFF00C4B4),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: isLoadingRecommendations
                        ? Column(
                            children: List.generate(
                              3,
                              (index) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Container(
                                  height: 90,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          )
                        : recommendationError != null
                            ? Center(
                                child: Text(
                                  recommendationError!,
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontFamily: 'Open Sans',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                            : recommendedProviders.isEmpty
                                ? Center(
                                    child: Text(
                                      'Search for a service to get recommendations!',
                                      style: TextStyle(
                                        fontFamily: 'Open Sans',
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  )
                                : Column(
                                    children: recommendedProviders
                                        .map((provider) => _buildServiceProviderCard(
                                              provider['name'],
                                              provider['service_type'],
                                              provider['score'] as double,
                                            ))
                                        .toList(),
                                  ),
                  ),
                  const SizedBox(height: 32),
                  // Featured Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: const Text(
                      'Featured',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                        color: Color(0xFF131010),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(child: _buildFeaturedImage()),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, '/booking');
              },
              backgroundColor: const Color(0xFF00C4B4),
              elevation: 8,
              child: const Icon(
                Icons.add,
                size: 28,
                color: Colors.white,
              ),
            ),
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              elevation: 12,
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
              currentIndex: _selectedIndex,
              selectedItemColor: const Color(0xFF00C4B4),
              unselectedItemColor: Colors.grey[400],
              onTap: _onItemTapped,
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceProviderCard(String name, String serviceType, double rating) {
    return Card(
      elevation: 5,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFF00C4B4).withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF00C4B4).withOpacity(0.1),
                child: const Icon(
                  Icons.person,
                  size: 32,
                  color: Color(0xFF00C4B4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontFamily: 'Montserrat',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF131010),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      serviceType,
                      style: TextStyle(
                        fontFamily: 'Open Sans',
                        color: Colors.grey[600],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star,
                    color: Color(0xFFFFC107),
                    size: 22,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontFamily: 'Open Sans',
                      color: Color(0xFF131010),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedImage() {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 3,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Image.network(
              featuredImageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Text(
                      'Failed to load advertisement',
                      style: TextStyle(
                        color: Color(0xFF131010),
                        fontFamily: 'Open Sans',
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              },
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.4),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C4B4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Featured Deal',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Montserrat',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryCard extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const CategoryCard({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  _CategoryCardState createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  bool _isTapped = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.02).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        setState(() {
          _isTapped = true;
        });
      },
      onTapUp: (_) {
        _controller.reverse();
        setState(() {
          _isTapped = false;
        });
        widget.onTap();
      },
      onTapCancel: () {
        _controller.reverse();
        setState(() {
          _isTapped = false;
        });
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform(
            transform: Matrix4.identity()
              ..scale(_scaleAnimation.value)
              ..rotateZ(_rotationAnimation.value),
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    const Color(0xFF00C4B4).withOpacity(_isTapped ? 0.15 : 0.1),
                    const Color(0xFF007A7A).withOpacity(_isTapped ? 0.1 : 0.05),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C4B4).withOpacity(_isTapped ? 0.2 : 0.1),
                    spreadRadius: _isTapped ? 3 : 2,
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: const Color(0xFF00C4B4).withOpacity(_isTapped ? 0.5 : 0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    size: 44,
                    color: const Color(0xFF00C4B4),
                    shadows: [
                      Shadow(
                        color: const Color(0xFF00C4B4).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF131010),
                      letterSpacing: 0.3,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}