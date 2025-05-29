import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fixme_new/features/auth/presentation/views/service_provider_profile_screen.dart';
import 'dart:convert';

class CategoryScreen extends StatefulWidget {
  final String category;

  const CategoryScreen({super.key, required this.category});

  @override
  _CategoryScreenState createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> providers = [];
  List<Map<String, dynamic>> filteredProviders = [];
  String userHometown = '';
  bool isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
    _loadData();
    _animationController.forward();
  }

  Future<void> _loadData() async {
    await _fetchUserHometown();
    await _fetchProviders();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserHometown() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        final snapshot = await FirebaseDatabase.instance
            .ref('users/${firebaseUser.uid}/hometown')
            .get();
        if (snapshot.exists) {
          setState(() {
            userHometown = snapshot.value.toString().trim();
          });
        }
      } catch (e) {
        print('Error fetching user hometown: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching hometown: $e')),
        );
      }
    }
  }

  Future<void> _fetchProviders() async {
    setState(() {
      isLoading = true;
    });
    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('users')
          .orderByChild('role')
          .equalTo('service_provider')
          .get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        print('Fetched providers data: $data'); // Debug log
        setState(() {
          providers = data.entries
              .where((entry) {
                final serviceProviderDetails =
                    entry.value['serviceProviderDetails'] as Map<dynamic, dynamic>?;
                // Changed 'serviceType' to 'category' to match Firebase data
                final category = serviceProviderDetails?['category']?.toString().trim();
                // Add status check to ensure only approved providers are shown
                final status = serviceProviderDetails?['status']?.toString().trim();
                final matchesCategory = serviceProviderDetails != null &&
                    category?.toLowerCase() == widget.category.trim().toLowerCase() &&
                    status == 'approved';
                print('Provider ${entry.key}: category=$category, status=$status, matches=$matchesCategory'); // Debug log
                return matchesCategory;
              })
              .map((entry) {
                final serviceProviderDetails =
                    entry.value['serviceProviderDetails'] as Map<dynamic, dynamic>;
                return {
                  'id': entry.key,
                  'name': entry.value['firstName'] as String? ?? 'Unknown',
                  'experience': (serviceProviderDetails['experience'] as num?)?.toDouble() ?? 0.0,
                  'location': serviceProviderDetails['location']?.toString().trim() ?? 'Unknown',
                  'profilePhoto': entry.value['profilePhoto']?.toString(),
                };
              })
              .toList();
          filteredProviders = List.from(providers);
          print('Filtered providers: $providers'); // Debug log
          _sortProvidersByHometownAndExperience();
        });
      } else {
        print('No service providers found for category: ${widget.category}');
      }
    } catch (e) {
      print('Error fetching providers: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching providers: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _sortProvidersByHometownAndExperience() {
    filteredProviders.sort((a, b) {
      bool aInHometown =
          userHometown.isNotEmpty && a['location'].toLowerCase() == userHometown.toLowerCase();
      bool bInHometown =
          userHometown.isNotEmpty && b['location'].toLowerCase() == userHometown.toLowerCase();

      if (aInHometown && !bInHometown) return -1;
      if (!aInHometown && bInHometown) return 1;

      if (aInHometown && bInHometown) {
        return (b['experience'] as num).compareTo(a['experience'] as num);
      }

      if (!aInHometown && !bInHometown) {
        return (b['experience'] as num).compareTo(a['experience'] as num);
      }

      return 0;
    });
  }

  List<Map<String, dynamic>> _filterProvidersByLocation(String query) {
    if (query.isEmpty) {
      return List.from(providers);
    }
    final filtered = providers
        .where((provider) =>
            provider['location'].toLowerCase().contains(query.toLowerCase()))
        .toList();

    filtered.sort((a, b) {
      if (a['location'].toLowerCase() == b['location'].toLowerCase()) {
        return (b['experience'] as num).compareTo(a['experience'] as num);
      }
      return 0;
    });

    return filtered;
  }

  void _showSearch() {
    showSearch(
      context: context,
      delegate: LocationSearchDelegate(
        providers: providers,
        userHometown: userHometown,
      ),
    ).then((result) {
      if (result != null) {
        setState(() {
          filteredProviders = _filterProvidersByLocation(result);
          _sortProvidersByHometownAndExperience();
        });
      }
    });
  }

  Widget _buildProfileImage(String? profilePhotoBase64) {
    if (profilePhotoBase64 != null && profilePhotoBase64.isNotEmpty) {
      try {
        final imageBytes = base64Decode(profilePhotoBase64);
        return CircleAvatar(
          radius: 30,
          backgroundColor: const Color(0xFF00C4B4),
          backgroundImage: MemoryImage(imageBytes),
        );
      } catch (e) {
        print('Error loading profile photo: $e');
        return _defaultAvatar();
      }
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return const CircleAvatar(
      radius: 30,
      backgroundColor: Color(0xFF00C4B4),
      child: Icon(
        Icons.person,
        size: 40,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF00C4B4),
        title: Text(
          widget.category,
          style: const TextStyle(
            fontFamily: 'londonbridgefontfamily',
            fontSize: 25,
            color: Colors.white,
          ),
        ),
        automaticallyImplyLeading: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.search,
              color: Colors.white,
            ),
            onPressed: _showSearch,
          ),
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: Colors.white,
            ),
            onPressed: _fetchProviders,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00C4B4),
              ),
            )
          : filteredProviders.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search,
                        size: 80,
                        color: Color(0xFF00C4B4),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No providers found for this category',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          color: Color(0xFF131010),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  itemCount: filteredProviders.length,
                  itemBuilder: (context, index) {
                    final isInHometown = userHometown.isNotEmpty &&
                        filteredProviders[index]['location'].toLowerCase() == userHometown.toLowerCase();
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ServiceProviderProfileScreen(
                                category: widget.category,
                                providerId: filteredProviders[index]['id'],
                              ),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 6,
                          margin: const EdgeInsets.only(bottom: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C4B4),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                children: [
                                  Stack(
                                    children: [
                                      _buildProfileImage(filteredProviders[index]['profilePhoto']),
                                      if (isInHometown)
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0288D1),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Text(
                                              'Near You',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontFamily: 'Roboto',
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          filteredProviders[index]['name'],
                                          style: const TextStyle(
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Experience: ${filteredProviders[index]['experience']} years',
                                          style: const TextStyle(
                                            fontFamily: 'Roboto',
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Location: ${filteredProviders[index]['location']}',
                                          style: const TextStyle(
                                            fontFamily: 'Roboto',
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
      bottomNavigationBar: _buildBottomNavigationBar(context, 0),
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

class LocationSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> providers;
  final String userHometown;

  LocationSearchDelegate({
    required this.providers,
    required this.userHometown,
  });

  Widget _buildProfileImage(String? profilePhotoBase64) {
    if (profilePhotoBase64 != null && profilePhotoBase64.isNotEmpty) {
      try {
        final imageBytes = base64Decode(profilePhotoBase64);
        return CircleAvatar(
          radius: 30,
          backgroundColor: const Color(0xFF00C4B4),
          backgroundImage: MemoryImage(imageBytes),
        );
      } catch (e) {
        print('Error loading profile photo: $e');
        return _defaultAvatar();
      }
    }
    return _defaultAvatar();
  }

  Widget _defaultAvatar() {
    return const CircleAvatar(
      radius: 30,
      backgroundColor: Color(0xFF00C4B4),
      child: Icon(
        Icons.person,
        size: 40,
        color: Colors.white,
      ),
    );
  }

  List<Map<String, dynamic>> _filterProviders(String query) {
    if (query.isEmpty) {
      return List.from(providers);
    }
    final filtered = providers
        .where((provider) =>
            provider['location'].toLowerCase().contains(query.toLowerCase()))
        .toList();

    filtered.sort((a, b) {
      if (a['location'].toLowerCase() == b['location'].toLowerCase()) {
        return (b['experience'] as num).compareTo(a['experience'] as num);
      }
      return 0;
    });

    return filtered;
  }

  void _sortProvidersByHometownAndExperience(List<Map<String, dynamic>> providersList) {
    providersList.sort((a, b) {
      bool aInHometown =
          userHometown.isNotEmpty && a['location'].toLowerCase() == userHometown.toLowerCase();
      bool bInHometown =
          userHometown.isNotEmpty && b['location'].toLowerCase() == userHometown.toLowerCase();

      if (aInHometown && !bInHometown) return -1;
      if (!aInHometown && bInHometown) return 1;

      if (aInHometown && bInHometown) {
        return (b['experience'] as num).compareTo(a['experience'] as num);
      }

      if (!aInHometown && !bInHometown) {
        return (b['experience'] as num).compareTo(a['experience'] as num);
      }

      return 0;
    });
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear, color: Colors.white),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        close(context, query);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final filtered = _filterProviders(query);
    _sortProvidersByHometownAndExperience(filtered);

    return filtered.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 80,
                  color: Color(0xFF00C4B4),
                ),
                SizedBox(height: 16),
                Text(
                  'No providers found for this location',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    color: Color(0xFF131010),
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final isInHometown = userHometown.isNotEmpty &&
                  filtered[index]['location'].toLowerCase() == userHometown.toLowerCase();
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ServiceProviderProfileScreen(
                        category: (context.widget as CategoryScreen).category,
                        providerId: filtered[index]['id'],
                      ),
                    ),
                  );
                },
                child: Card(
                  elevation: 6,
                  margin: const EdgeInsets.only(bottom: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C4B4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              _buildProfileImage(filtered[index]['profilePhoto']),
                              if (isInHometown)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0288D1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Near You',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontFamily: 'Roboto',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  filtered[index]['name'],
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Experience: ${filtered[index]['experience']} years',
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Location: ${filtered[index]['location']}',
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final suggestions = _filterProviders(query);
    _sortProvidersByHometownAndExperience(suggestions);

    return suggestions.isEmpty
        ? const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off,
                  size: 80,
                  color: Color(0xFF00C4B4),
                ),
                SizedBox(height: 16),
                Text(
                  'No providers found for this location',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 16,
                    color: Color(0xFF131010),
                  ),
                ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  query = suggestions[index]['location'];
                  showResults(context);
                },
                child: ListTile(
                  title: Text(
                    suggestions[index]['location'],
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 16,
                      color: Color(0xFF131010),
                    ),
                  ),
                  subtitle: Text(
                    'Experience: ${suggestions[index]['experience']} years',
                    style: const TextStyle(
                      fontFamily: 'Roboto',
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            },
          );
  }

  @override
  ThemeData appBarTheme(BuildContext context) {
    return ThemeData(
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF00C4B4),
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(
          color: Colors.white70,
          fontFamily: 'Roboto',
        ),
        border: InputBorder.none,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontFamily: 'londonbridgefontfamily',
        ),
      ),
    );
  }

  @override
  String get searchFieldLabel => 'Search by location';
}