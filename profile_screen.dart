import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fixme_new/features/auth/data/models/service_provider_details.dart';
import 'package:fixme_new/features/auth/presentation/views/ServiceProviderRegistrationScreen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:developer';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fl_chart/fl_chart.dart';
import 'phone_input_screen.dart';
import '../viewmodels/auth_viewmodel.dart';

// Data model for booking chart
class BookingData {
  final String category;
  final int count;

  BookingData(this.category, this.count);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  String firstName = 'User';
  String hometown = '';
  String phoneNumber = '';
  String role = 'customer';
  String? profilePhotoBase64;
  String? coverPhotoBase64;
  File? _profilePhotoFile;
  File? _coverPhotoFile;
  Map<dynamic, dynamic>? serviceProviderDetails;
  bool isEditingProfile = false;
  bool isEditingServiceDetails = false;
  bool isUploading = false;
  bool isLoading = true;
  bool isPhoneVerified = false;
  ServiceProviderDetails? providerDetails;
  List<String> photos = [];
  List<Map<String, dynamic>> reviews = [];
  List<Map<String, dynamic>> ongoingBookings = [];
  List<Map<String, dynamic>> completedBookings = [];
  List<Map<String, dynamic>> cancelledBookings = [];
  TabController? _tabController;

  // Controllers for profile fields
  final _firstNameController = TextEditingController();
  final _hometownController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  // Controllers for service provider details
  final _experienceController = TextEditingController();
  final _locationController = TextEditingController();
  final _workingAreasController = TextEditingController();
  final _rateController = TextEditingController();
  final _bioController = TextEditingController();
  final _skillsController = TextEditingController();
  final _additionalServicesController = TextEditingController();
  final _businessNameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  String? _selectedCategory;
  String? _selectedPaymentType;

  final List<String> _categories = [
    'Plumbing',
    'Electrical',
    'Mechanic',
    'Cleaning',
    'Painting',
    'A/C Repair',
    'Painter',
    'Meson',
    'Caregiver',
    'Home appliance repairing',
  ];
  final List<String> _paymentTypes = ['Hourly', 'Square Feet', 'Fixed Rate'];

  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchUserDetails();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _hometownController.dispose();
    _phoneNumberController.dispose();
    _experienceController.dispose();
    _locationController.dispose();
    _workingAreasController.dispose();
    _rateController.dispose();
    _bioController.dispose();
    _skillsController.dispose();
    _additionalServicesController.dispose();
    _businessNameController.dispose();
    _bankAccountController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchUserDetails() async {
    setState(() {
      isLoading = true;
    });

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      try {
        final snapshot = await FirebaseDatabase.instance
            .ref('users/${firebaseUser.uid}')
            .get();
        if (snapshot.exists) {
          final data = snapshot.value as Map<dynamic, dynamic>;
          log('User Data: $data');
          setState(() {
            firstName = data['firstName']?.toString() ?? 'User';
            hometown = data['hometown']?.toString() ?? '';
            phoneNumber = data['phoneNumber']?.toString() ?? '';
            role = data['role']?.toString() ?? 'customer';
            profilePhotoBase64 = data['profilePhoto']?.toString();
            coverPhotoBase64 = data['coverPhoto']?.toString();
            serviceProviderDetails = data['serviceProviderDetails'];
            isPhoneVerified = data['isPhoneVerified'] == true;
            log('Service Provider Details in _fetchUserDetails: $serviceProviderDetails');
            _firstNameController.text = firstName;
            _hometownController.text = hometown;
            _phoneNumberController.text = phoneNumber;

            if (role == 'service_provider' && serviceProviderDetails != null) {
              providerDetails = ServiceProviderDetails.fromMap(
                  Map<String, dynamic>.from(serviceProviderDetails!));
              photos =
                  providerDetails!.previousWorksIMAGES?.values.cast<String>().toList() ??
                      [];
              reviews = providerDetails!.reviews?.entries.map((entry) {
                return {
                  'user': entry.value['user'] as String? ?? 'Unknown',
                  'comment': entry.value['comment'] as String? ?? '',
                  'rating': entry.value['rating'] as num? ?? 0,
                };
              }).toList() ??
                  [];
              _fetchBookings();

              _experienceController.text =
                  serviceProviderDetails!['experience']?.toString() ?? '';
              _locationController.text =
                  serviceProviderDetails!['location']?.toString() ?? '';
              _workingAreasController.text =
                  serviceProviderDetails!['workingAreas']?.join(', ') ?? '';
              _rateController.text =
                  serviceProviderDetails!['rate']?.toString() ?? '';
              _bioController.text =
                  serviceProviderDetails!['bio']?.toString() ?? '';
              _skillsController.text =
                  serviceProviderDetails!['skills']?.toString() ?? '';
              _additionalServicesController.text =
                  serviceProviderDetails!['additionalServices']?.toString() ??
                      '';
              _businessNameController.text =
                  serviceProviderDetails!['businessName']?.toString() ?? '';
              _bankAccountController.text =
                  serviceProviderDetails!['bankAccount']?.toString() ?? '';
              _selectedCategory =
                  serviceProviderDetails!['category']?.toString();
              _selectedPaymentType = _paymentTypes.firstWhere(
                (type) =>
                    type.toLowerCase() ==
                    (serviceProviderDetails!['payment_type']?.toString() ??
                        'fixedrate'),
                orElse: () => 'Fixed Rate',
              );
            }
            isLoading = false;
          });
        } else {
          setState(() {
            isLoading = false;
          });
        }
      } catch (e) {
        log('Error fetching user details: $e');
        _showSnackBar('Error fetching profile: $e');
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchBookings() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final providerId = user.uid;

      final snapshot = await FirebaseDatabase.instance
          .ref('notifications/$providerId')
          .get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          ongoingBookings.clear();
          completedBookings.clear();
          cancelledBookings.clear();

          for (var entry in data.entries) {
            final notificationData = entry.value as Map<dynamic, dynamic>;
            final booking = {
              'notification_id': entry.key,
              'user_id': notificationData['user_id'] as String? ?? '',
              'category': notificationData['category'] as String? ?? 'Unknown',
              'status': notificationData['status'] as String? ?? 'Pending',
              'timestamp': notificationData['timestamp'] as String? ??
                  DateTime.now().toIso8601String(),
              'customer_name':
                  notificationData['customer_name'] as String? ?? 'Unknown',
              'customer_location':
                  notificationData['customer_location'] as String? ?? 'Unknown',
              'coordinates':
                  notificationData['coordinates'] as String? ?? '0,0',
            };
            if (booking['status'] == 'Pending' ||
                booking['status'] == 'Accepted') {
              ongoingBookings.add(booking);
            } else if (booking['status'] == 'Completed') {
              completedBookings.add(booking);
            } else if (booking['status'] == 'Declined') {
              cancelledBookings.add(booking);
            }
          }
        });
      }
    } catch (e) {
      log('Error fetching bookings: $e');
    }
  }

  Future<void> _completeBooking(String notificationId, String userId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnackBar('User not authenticated.');
        return;
      }
      final providerId = user.uid;
      log('Provider ID: $providerId');

      if (serviceProviderDetails == null) {
        _showSnackBar('Service provider details not found.');
        return;
      }

      final providerDetails = serviceProviderDetails!;
      log('Provider Details: $providerDetails');
      log('Provider Details Keys: ${providerDetails.keys.toList()}');

      if (!providerDetails.containsKey('payment_type')) {
        _showSnackBar('Payment type not specified for this provider.');
        return;
      }
      String paymentType =
          providerDetails['payment_type']?.toString() ?? 'fixedrate';
      log('Payment Type: $paymentType');

      final rate = (providerDetails['rate'] as num?)?.toDouble() ?? 0.0;
      if (rate <= 0) {
        _showSnackBar('Invalid rate specified for this provider.');
        return;
      }
      log('Rate: $rate');

      final bookingSnapshot = await FirebaseDatabase.instance
          .ref('notifications/$providerId/$notificationId')
          .get();
      if (!bookingSnapshot.exists) {
        _showSnackBar('Booking not found.');
        return;
      }
      final bookingData = bookingSnapshot.value as Map<dynamic, dynamic>;
      final category = bookingData['category']?.toString() ?? 'Unknown';

      await _showCompleteBookingPopup(
        context: context,
        paymentType: paymentType,
        rate: rate,
        onSubmit: (double totalAmount, double? inputValue) async {
          String? bookingId;
          final bookingSnapshot = await FirebaseDatabase.instance
              .ref('bookings/$userId')
              .orderByChild('provider_id')
              .equalTo(providerId)
              .get();
          if (bookingSnapshot.exists) {
            final bookings = bookingSnapshot.value as Map<dynamic, dynamic>;
            for (var entry in bookings.entries) {
              if (entry.value['provider_id'] == providerId &&
                  (entry.value['status'] == 'Pending' ||
                      entry.value['status'] == 'Accepted')) {
                bookingId = entry.key;
                break;
              }
            }
          }

          await _saveBillingData(
            providerId: providerId,
            userId: userId,
            bookingId: bookingId ?? '',
            notificationId: notificationId,
            category: category,
            paymentType: paymentType,
            rate: rate,
            inputValue: inputValue,
            totalAmount: totalAmount,
          );

          await FirebaseDatabase.instance
              .ref('notifications/$providerId/$notificationId')
              .update({'status': 'Completed'});

          if (bookingId != null) {
            await FirebaseDatabase.instance
                .ref('bookings/$userId/$bookingId')
                .update({'status': 'Completed'});
          }

          final providerSnapshot = await FirebaseDatabase.instance
              .ref('users/$providerId')
              .get();
          String providerName = providerSnapshot.exists
              ? (providerSnapshot.value as Map)['firstName'] as String? ??
                  'Unknown'
              : 'Unknown';

          await FirebaseDatabase.instance
              .ref('customer_notifications/$userId')
              .push()
              .set({
            'message': 'Your booking has been completed by $providerName.',
            'type': 'Completed',
            'booking_id': bookingId ?? '',
            'timestamp': DateTime.now().toIso8601String(),
            'read': false,
          });

          await _fetchBookings();
          _showSnackBar('Booking marked as completed');
        },
      );
    } catch (e) {
      log('Error completing booking: $e');
      _showSnackBar('Error completing booking: $e');
    }
  }

  Future<void> _showCompleteBookingPopup({
    required BuildContext context,
    required String paymentType,
    required double rate,
    required Function(double, double?) onSubmit,
  }) async {
    final normalizedPaymentType = paymentType.toLowerCase();
    log('Normalized Payment Type: $normalizedPaymentType');

    if (!['fixedrate', 'hourly', 'squarefeet']
        .contains(normalizedPaymentType)) {
      log('Invalid payment type: $normalizedPaymentType, defaulting to fixedrate');
      _showSnackBar('Invalid payment type detected. Defaulting to fixed rate.');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Complete Booking',
            style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Payment Type: Fixed Rate\nTotal Amount: ${rate.toStringAsFixed(2)} LKR',
            style: const TextStyle(fontFamily: 'Open Sans'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey, fontFamily: 'Open Sans'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onSubmit(rate, null);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C4B4),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
      return;
    }

    if (normalizedPaymentType == 'fixedrate') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Complete Booking',
            style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Payment Type: Fixed Rate\nTotal Amount: ${rate.toStringAsFixed(2)} LKR',
            style: const TextStyle(fontFamily: 'Open Sans'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey, fontFamily: 'Open Sans'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onSubmit(rate, null);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C4B4),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    } else if (normalizedPaymentType == 'hourly' ||
        normalizedPaymentType == 'squarefeet') {
      final TextEditingController inputController = TextEditingController();
      final String inputLabel =
          normalizedPaymentType == 'hourly' ? 'Hours Worked' : 'Square Feet';
      final String unitLabel =
          normalizedPaymentType == 'hourly' ? 'hour' : 'square foot';

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Complete Booking',
            style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Payment Type: ${normalizedPaymentType == 'hourly' ? 'Hourly' : 'Square Feet'}',
                style: const TextStyle(fontFamily: 'Open Sans'),
              ),
              const SizedBox(height: 8),
              Text(
                'Rate: ${rate.toStringAsFixed(2)} LKR per $unitLabel',
                style: const TextStyle(fontFamily: 'Open Sans'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: inputController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: inputLabel,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey, fontFamily: 'Open Sans'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final inputValue = double.tryParse(inputController.text);
                if (inputValue == null || inputValue <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid value')),
                  );
                  return;
                }
                final totalAmount = inputValue * rate;
                Navigator.pop(context);
                onSubmit(totalAmount, inputValue);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C4B4),
                foregroundColor: Colors.white,
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _saveBillingData({
    required String providerId,
    required String userId,
    required String bookingId,
    required String notificationId,
    required String category,
    required String paymentType,
    required double rate,
    required double? inputValue,
    required double totalAmount,
  }) async {
    try {
      final billingRef = FirebaseDatabase.instance.ref('billing').push();
      await billingRef.set({
        'provider_id': providerId,
        'user_id': userId,
        'booking_id': bookingId,
        'notification_id': notificationId,
        'category': category,
        'payment_type': paymentType,
        'rate': rate,
        'input_value': inputValue,
        'total_amount': totalAmount,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'pending',
      });
    } catch (e) {
      log('Error saving billing data: $e');
      _showSnackBar('Error saving billing data: $e');
    }
  }

  Future<void> _showPhotoSourceOptions({required bool isCoverPhoto}) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF00C4B4)),
              title: const Text('Choose from Gallery',
                  style: TextStyle(fontFamily: 'Montserrat')),
              onTap: () {
                Navigator.pop(context);
                _pickImageFrom(ImageSource.gallery, isCoverPhoto: isCoverPhoto);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF00C4B4)),
              title: const Text('Take a Photo',
                  style: TextStyle(fontFamily: 'Montserrat')),
              onTap: () {
                Navigator.pop(context);
                _pickImageFrom(ImageSource.camera, isCoverPhoto: isCoverPhoto);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFrom(ImageSource source,
      {required bool isCoverPhoto}) async {
    try {
      if (!_imagePicker.supportsImageSource(source)) {
        _showSnackBar(
            '${source == ImageSource.camera ? "Camera" : "Gallery"} is not supported on this device.');
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 50,
      );

      if (image == null) {
        _showSnackBar('Image selection cancelled.');
        return;
      }

      setState(() => isUploading = true);

      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        image.path,
        '${image.path}_compressed.jpg',
        quality: 50,
      );

      if (compressedImage == null) {
        setState(() => isUploading = false);
        _showSnackBar('Image compression failed.');
        return;
      }

      CroppedFile? croppedFile;
      try {
        croppedFile = await ImageCropper().cropImage(
          sourcePath: compressedImage.path,
          aspectRatio: isCoverPhoto
              ? const CropAspectRatio(ratioX: 16, ratioY: 9)
              : const CropAspectRatio(ratioX: 1, ratioY: 1),
          compressQuality: 50,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle:
                  isCoverPhoto ? 'Crop Cover Photo' : 'Crop Profile Photo',
              toolbarColor: const Color(0xFF00C4B4),
              toolbarWidgetColor: Colors.white,
              initAspectRatio: isCoverPhoto
                  ? CropAspectRatioPreset.ratio16x9
                  : CropAspectRatioPreset.square,
              lockAspectRatio: true,
            ),
            IOSUiSettings(
              title: isCoverPhoto ? 'Crop Cover Photo' : 'Crop Profile Photo',
              aspectRatioLockEnabled: true,
            ),
          ],
        );
      } catch (cropError) {
        log('Error cropping image, using original: $cropError');
        croppedFile = CroppedFile(compressedImage.path);
      }

      if (croppedFile == null) {
        setState(() => isUploading = false);
        _showSnackBar('Image cropping cancelled or failed.');
        return;
      }

      final File file = File(croppedFile.path);
      final fileSize = await file.length();
      if (fileSize > 1024 * 1024) {
        setState(() => isUploading = false);
        _showSnackBar('Image size is too large. Please select a smaller image.');
        return;
      }

      setState(() {
        if (isCoverPhoto) {
          _coverPhotoFile = file;
        } else {
          _profilePhotoFile = file;
        }
        isUploading = false;
      });
    } catch (e) {
      setState(() => isUploading = false);
      log('Error in _pickImageFrom: $e');
      _showSnackBar('Error processing image: $e');
    }
  }

  Future<String?> _convertImageToBase64(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return base64Encode(bytes);
    } catch (e) {
      log('Error converting image to base64: $e');
      return null;
    }
  }

  Future<void> _updateUserDetails() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;

    if (_firstNameController.text.trim().isEmpty) {
      _showSnackBar('First name cannot be empty');
      return;
    }

    setState(() => isUploading = true);

    try {
      final updates = {
        'firstName': _firstNameController.text.trim(),
        'hometown': _hometownController.text.trim(),
        'phoneNumber': _phoneNumberController.text.trim(),
      };

      if (_profilePhotoFile != null) {
        final base64Image = await _convertImageToBase64(_profilePhotoFile!);
        if (base64Image != null) {
          updates['profilePhoto'] = base64Image;
          profilePhotoBase64 = base64Image;
        }
      }

      if (_coverPhotoFile != null) {
        final base64Image = await _convertImageToBase64(_coverPhotoFile!);
        if (base64Image != null) {
          updates['coverPhoto'] = base64Image;
          coverPhotoBase64 = base64Image;
        }
      }

      await FirebaseDatabase.instance
          .ref('users/${firebaseUser.uid}')
          .update(updates);

      setState(() {
        firstName = _firstNameController.text.trim();
        hometown = _hometownController.text.trim();
        phoneNumber = _phoneNumberController.text.trim();
        isEditingProfile = false;
        isUploading = false;
        _profilePhotoFile = null;
        _coverPhotoFile = null;
      });
      _showSnackBar('Profile updated successfully!');
    } catch (e) {
      setState(() => isUploading = false);
      log('Error updating user details: $e');
      _showSnackBar('Failed to update profile: $e');
    }
  }

  Future<void> _updateServiceDetails() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) {
      _showSnackBar('User not authenticated');
      return;
    }

    if (_experienceController.text.isEmpty ||
        _locationController.text.isEmpty ||
        _workingAreasController.text.isEmpty ||
        _rateController.text.isEmpty ||
        _selectedCategory == null ||
        _selectedPaymentType == null ||
        _bankAccountController.text.isEmpty) {
      _showSnackBar('Please fill all required fields');
      return;
    }

    try {
      final experience = double.parse(_experienceController.text);
      final rate = double.parse(_rateController.text);

      if (experience < 0 || rate < 0) {
        _showSnackBar('Experience and rate must be positive numbers');
        return;
      }

      String normalizedPaymentType;
      switch (_selectedPaymentType) {
        case 'Hourly':
          normalizedPaymentType = 'hourly';
          break;
        case 'Square Feet':
          normalizedPaymentType = 'squarefeet';
          break;
        case 'Fixed Rate':
          normalizedPaymentType = 'fixedrate';
          break;
        default:
          normalizedPaymentType = 'fixedrate';
      }

      final updates = {
        'serviceProviderDetails': {
          'status': serviceProviderDetails?['status'] ?? 'pending',
          'category': _selectedCategory,
          'experience': experience,
          'location': _locationController.text,
          'workingAreas':
              _workingAreasController.text.split(',').map((e) => e.trim()).toList(),
          'payment_type': normalizedPaymentType,
          'rate': rate,
          'businessName': _businessNameController.text,
          'bio': _bioController.text,
          'skills': _skillsController.text,
          'additionalServices': _additionalServicesController.text,
          'bankAccount': _bankAccountController.text,
          'photos': serviceProviderDetails?['photos'],
          'reviews': serviceProviderDetails?['reviews'],
        },
      };

      await FirebaseDatabase.instance
          .ref('users/${firebaseUser.uid}')
          .update(updates);

      setState(() {
        serviceProviderDetails = updates['serviceProviderDetails'];
        isEditingServiceDetails = false;
      });
      _showSnackBar('Service details updated successfully!');
    } catch (e) {
      log('Error updating service details: $e');
      _showSnackBar('Failed to update service details: $e');
    }
  }

  Future<void> _verifyDetails() async {
    final phoneNumber = _phoneNumberController.text.trim();
    if (phoneNumber.isEmpty) {
      _showSnackBar('Please enter a phone number');
      return;
    }
    // Validate E.164 format: +[country code][subscriber number]
    final e164Regex = RegExp(r'^\+[1-9]\d{1,14}$');
    if (!e164Regex.hasMatch(phoneNumber)) {
      _showSnackBar('Please enter a valid phone number in E.164 format (e.g., +9470123456)');
      return;
    }
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PhoneInputScreen(initialPhoneNumber: phoneNumber),
        ),
      );
      if (result == true) {
        await _fetchUserDetails(); // Refresh to ensure isPhoneVerified updates
        _showSnackBar('Phone number verified successfully!');
      } else {
        _showSnackBar('Verification cancelled or failed');
      }
    } catch (e) {
      _showSnackBar('Error during verification: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Open Sans'),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        backgroundColor: const Color(0xFF00C4B4),
      ),
    );
  }

  Widget _buildProfileImage() {
    if (_profilePhotoFile != null) {
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.white,
        backgroundImage: FileImage(_profilePhotoFile!),
      );
    } else if (profilePhotoBase64 != null && profilePhotoBase64!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(profilePhotoBase64!);
        return CircleAvatar(
          radius: 60,
          backgroundColor: Colors.white,
          backgroundImage: MemoryImage(imageBytes),
        );
      } catch (e) {
        log('Error decoding profile image: $e');
        return _defaultAvatar();
      }
    }
    return _defaultAvatar();
  }

  Widget _buildCoverImage() {
    if (_coverPhotoFile != null) {
      return Image.file(
        _coverPhotoFile!,
        fit: BoxFit.cover,
        height: 200,
        width: double.infinity,
      );
    } else if (coverPhotoBase64 != null && coverPhotoBase64!.isNotEmpty) {
      try {
        final imageBytes = base64Decode(coverPhotoBase64!);
        return Image.memory(
          imageBytes,
          fit: BoxFit.cover,
          height: 200,
          width: double.infinity,
        );
      } catch (e) {
        log('Error decoding cover image: $e');
        return _defaultCover();
      }
    }
    return _defaultCover();
  }

  Widget _defaultAvatar() {
    return CircleAvatar(
      radius: 60,
      backgroundColor: Colors.white,
      child: Icon(
        Icons.person,
        size: 70,
        color: const Color(0xFF00C4B4),
      ),
    );
  }

  Widget _defaultCover() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF00C4B4), Color(0xFF80DEEA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontFamily: 'Open Sans',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF131010),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'Open Sans',
              fontSize: 16,
              color: Color(0xFF131010),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    String? hint,
    IconData? icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF5FBFF),
            Color(0xFFE8F4FA),
          ],
        ),
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
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: Color(0xFF00C4B4)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00C4B4), width: 2.0),
          ),
          filled: true,
          fillColor: Colors.transparent,
          prefixIcon: icon != null
              ? Icon(
                  icon,
                  color: const Color(0xFF00C4B4),
                  size: 20,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        ),
        style: const TextStyle(
          fontFamily: 'Open Sans',
          fontSize: 16,
          color: Color(0xFF131010),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String? value,
    required String label,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF5FBFF),
            Color(0xFFE8F4FA),
          ],
        ),
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
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontFamily: 'Open Sans',
            fontSize: 16,
            color: Colors.grey,
          ),
          prefixIcon: icon != null
              ? Icon(
                  icon,
                  color: const Color(0xFF00C4B4),
                  size: 20,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF00C4B4),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        items: items.map((item) {
          return DropdownMenuItem(
            value: item,
            child: Text(
              item,
              style: const TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 16,
                color: Color(0xFF131010),
              ),
            ),
          );
        }).toList(),
        onChanged: onChanged,
        dropdownColor: const Color(0xFFF5FBFF),
        icon: const Icon(
          Icons.arrow_drop_down,
          color: Color(0xFF00C4B4),
        ),
      ),
    );
  }

  Widget _buildBookingList(List<Map<String, dynamic>> bookings,
      bool showCompleteButton) {
    return bookings.isEmpty
        ? const Center(
            child: Text(
              'No bookings',
              style: TextStyle(
                fontFamily: 'Open Sans',
                fontSize: 16,
                color: Color(0xFF131010),
              ),
            ),
          )
        : ListView.builder(
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 25,
                        backgroundColor: Color(0xFF00C4B4),
                        child: Icon(Icons.person, size: 30, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking['category'] ?? 'Unknown Service',
                              style: const TextStyle(
                                fontFamily: 'Montserrat',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFF131010),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Customer: ${booking['customer_name']}',
                              style: const TextStyle(
                                fontFamily: 'Open Sans',
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (showCompleteButton && booking['status'] == 'Accepted')
                        ElevatedButton(
                          onPressed: () => _completeBooking(
                              booking['notification_id'], booking['user_id']),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C4B4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          child: const Text(
                            'Complete',
                            style: TextStyle(
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _buildBottomNavigationBar(BuildContext context, int selectedIndex) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: const Color(0xFF00C4B4),
      items: const [
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
            break;
        }
      },
    );
  }

  void _showServiceDetailsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF0F8FF),
                Color(0xFFE6F3FA),
              ],
            ),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Update Business Details',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF131010),
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _locationController,
                  'Location *',
                  icon: Icons.location_on,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _workingAreasController,
                  'Working Areas (comma-separated) *',
                  hint: 'e.g., Colombo, Kandy',
                  icon: Icons.map,
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.grey, thickness: 0.5),
                const SizedBox(height: 24),
                const Text(
                  'Service Details',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF131010),
                  ),
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  value: _selectedCategory,
                  label: 'Category *',
                  items: _categories,
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                  icon: Icons.build,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _experienceController,
                  'Experience (years) *',
                  icon: Icons.work_history,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _skillsController,
                  'Skills',
                  icon: Icons.handyman,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _bioController,
                  'Bio',
                  icon: Icons.description,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _additionalServicesController,
                  'Additional Services',
                  icon: Icons.add_circle,
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.grey, thickness: 0.5),
                const SizedBox(height: 24),
                const Text(
                  'Business & Payment',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF131010),
                  ),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _businessNameController,
                  'Business Name',
                  icon: Icons.business,
                ),
                const SizedBox(height: 16),
                _buildDropdownField(
                  value: _selectedPaymentType,
                  label: 'Payment Type *',
                  items: _paymentTypes,
                  onChanged: (value) {
                    setState(() {
                      _selectedPaymentType = value;
                    });
                  },
                  icon: Icons.payment,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _rateController,
                  'Rate *',
                  icon: Icons.attach_money,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  _bankAccountController,
                  'Bank Account Number *',
                  icon: Icons.account_balance,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 40),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            isEditingServiceDetails = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () {
                          _updateServiceDetails();
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00C4B4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 40, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          'Save',
                          style: TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
      ),
    );
  }

  List<BookingData> _createBookingData() {
    final monthCounts = <String, int>{};
    for (var booking in completedBookings) {
      final timestamp = booking['timestamp'] as String? ?? DateTime.now().toIso8601String();
      try {
        DateTime date;
        // Check if the timestamp is in the format "YYYY-MM"
        if (RegExp(r'^\d{4}-\d{2}$').hasMatch(timestamp)) {
          // Append a default day and time to make it a valid ISO 8601 string
          date = DateTime.parse("${timestamp}-01T00:00:00Z");
        } else {
          // Try parsing as a full ISO 8601 string
          date = DateTime.parse(timestamp);
        }
        final monthYear = "${_getMonthName(date.month)} ${date.year}";
        monthCounts[monthYear] = (monthCounts[monthYear] ?? 0) + 1;
      } catch (e) {
        log('Error parsing timestamp: $timestamp, error: $e');
        continue; // Skip invalid timestamps
      }
    }

    final sortedKeys = monthCounts.keys.toList()
      ..sort((a, b) {
        final aDate = DateTime.parse(
            "${a.split(' ')[1]}-${_getMonthNumber(a.split(' ')[0]).toString().padLeft(2, '0')}-01");
        final bDate = DateTime.parse(
            "${b.split(' ')[1]}-${_getMonthNumber(b.split(' ')[0]).toString().padLeft(2, '0')}-01");
        return aDate.compareTo(bDate);
      });

    return sortedKeys.map((monthYear) {
      return BookingData(monthYear, monthCounts[monthYear]!);
    }).toList();
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  int _getMonthNumber(String month) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
      'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    return months[month] ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final bookingData = _createBookingData();
    return Consumer<AuthViewModel>(
      builder: (context, authViewModel, child) {
        return WillPopScope(
          onWillPop: () async {
            Navigator.pushReplacementNamed(context, '/home');
            return false;
          },
          child: Scaffold(
            backgroundColor: const Color(0xFFF5F7FA),
            floatingActionButton: FloatingActionButton(
              backgroundColor: const Color(0xFF00C4B4),
              onPressed: isUploading
                  ? null
                  : () {
                      if (isEditingProfile) {
                        _updateUserDetails();
                      } else {
                        setState(() => isEditingProfile = true);
                        _showPhotoSourceOptions(isCoverPhoto: false);
                      }
                    },
              child: Icon(
                isEditingProfile ? Icons.save : Icons.edit,
                color: Colors.white,
              ),
            ),
            bottomNavigationBar: _buildBottomNavigationBar(context, 3),
            body: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF00C4B4),
                    ),
                  )
                : isUploading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                                color: Color(0xFF00C4B4)),
                            const SizedBox(height: 16),
                            Text(
                              'Updating profile...',
                              style: TextStyle(
                                fontFamily: 'Montserrat',
                                color: const Color(0xFF131010),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchUserDetails,
                        color: const Color(0xFF00C4B4),
                        child: CustomScrollView(
                          slivers: [
                            SliverAppBar(
                              expandedHeight: 250,
                              floating: false,
                              pinned: true,
                              backgroundColor: const Color(0xFF00C4B4),
                              flexibleSpace: FlexibleSpaceBar(
                                background: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _buildCoverImage(),
                                    Align(
                                      alignment: Alignment.center,
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 40.0),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            GestureDetector(
                                              onTap: isEditingProfile ? () => _showPhotoSourceOptions(isCoverPhoto: false) : null,
                                              child: Hero(
                                                tag: 'profile_image',
                                                child: _buildProfileImage(),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              firstName.toUpperCase(),
                                              style: const TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    if (isEditingProfile)
                                      Positioned(
                                        bottom: 10,
                                        right: 10,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.white,
                                            size: 30,
                                          ),
                                          onPressed: () =>
                                              _showPhotoSourceOptions(
                                                  isCoverPhoto: true),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              title: Text(
                                'Profile',
                                style: TextStyle(
                                  fontFamily: 'Montserrat',
                                  fontSize: 25,
                                  color: Colors.white,
                                ),
                              ),
                              actions: [
                                IconButton(
                                  icon: const Icon(Icons.logout,
                                      color: Colors.white),
                                  onPressed: isUploading
                                      ? null
                                      : () async {
                                          await authViewModel.signOut();
                                          Navigator.pushReplacementNamed(
                                              context, '/sign-in');
                                        },
                                ),
                              ],
                            ),
                            SliverToBoxAdapter(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [const Color(0xFFF0F8FF).withOpacity(0.9), const Color(0xFFE6F3FA).withOpacity(0.9)],
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Personal Details',
                                        style: TextStyle(
                                          fontFamily: 'Montserrat',
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF131010),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Card(
                                        elevation: 6,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          padding: const EdgeInsets.all(16.0),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                const Color(0xFFF5FBFF).withOpacity(0.8),
                                                const Color(0xFFE8F4FA).withOpacity(0.8),
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: !isEditingProfile
                                              ? Column(
                                                  children: [
                                                    _buildProfileField('First Name', firstName),
                                                    const SizedBox(height: 12),
                                                    _buildProfileField('Hometown', hometown.isEmpty ? 'Not set' : hometown),
                                                    const SizedBox(height: 12),
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: _buildProfileField('Phone Number', phoneNumber.isEmpty ? 'Not set' : phoneNumber),
                                                        ),
                                                        if (!isPhoneVerified)
                                                          Icon(
                                                            Icons.warning_amber_rounded,
                                                            color: Colors.red,
                                                            size: 20,
                                                          ),
                                                      ],
                                                    ),
                                                    if (!isPhoneVerified) const SizedBox(height: 20),
                                                    if (!isPhoneVerified)
                                                      Container(
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
                                                          onPressed: isPhoneVerified ? null : _verifyDetails,
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.transparent,
                                                            foregroundColor: Colors.white,
                                                            minimumSize: const Size(double.infinity, 50),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius: BorderRadius.circular(12),
                                                            ),
                                                            elevation: 0,
                                                          ),
                                                          child: const Text(
                                                            'Verify Phone Number',
                                                            style: TextStyle(
                                                              fontFamily: 'Poppins',
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                )
                                              : Column(
                                                  children: [
                                                    _buildTextField(_firstNameController, 'First Name'),
                                                    const SizedBox(height: 12),
                                                    _buildTextField(_hometownController, 'Hometown'),
                                                    const SizedBox(height: 12),
                                                    _buildTextField(_phoneNumberController, 'Phone Number', keyboardType: TextInputType.phone),
                                                    const SizedBox(height: 20),
                                                    ElevatedButton(
                                                      onPressed: isPhoneVerified ? null : _verifyDetails,
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFF00C4B4),
                                                        foregroundColor: Colors.white,
                                                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                        elevation: 4,
                                                      ),
                                                      child: const Text(
                                                        'Verify',
                                                        style: TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                      if (role == 'service_provider' && serviceProviderDetails != null) ...[
                                        const SizedBox(height: 32),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Service Analytics',
                                              style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF131010),
                                              ),
                                            ),
                                            const Icon(Icons.analytics, color: Color(0xFF00C4B4), size: 24),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Card(
                                          elevation: 6,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [const Color(0xFFF5FBFF), const Color(0xFFE8F4FA)],
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: bookingData.isEmpty
                                                ? const Center(
                                                    child: Text(
                                                      'No service data available',
                                                      style: TextStyle(fontFamily: 'Open Sans', fontSize: 16, color: Colors.grey),
                                                    ),
                                                  )
                                                : SizedBox(
                                                    height: 200,
                                                    child: BarChart(
                                                      BarChartData(
                                                        alignment: BarChartAlignment.spaceAround,
                                                        barTouchData: BarTouchData(
                                                          enabled: true,
                                                          touchTooltipData: BarTouchTooltipData(
                                                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                                              return BarTooltipItem(
                                                                '${bookingData[groupIndex].category}: ${rod.toY.toInt()} bookings',
                                                                const TextStyle(color: Colors.white, fontFamily: 'Open Sans', fontSize: 12),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                        barGroups: bookingData.asMap().entries.map((entry) {
                                                          final index = entry.key;
                                                          final data = entry.value;
                                                          return BarChartGroupData(
                                                            x: index,
                                                            barRods: [
                                                              BarChartRodData(
                                                                toY: data.count.toDouble(),
                                                                color: [const Color(0xFF00C4B4), Colors.tealAccent, Colors.cyan, Colors.blueAccent][index % 4],
                                                                width: 18,
                                                                borderRadius: BorderRadius.circular(8),
                                                              ),
                                                            ],
                                                          );
                                                        }).toList(),
                                                        titlesData: FlTitlesData(
                                                          bottomTitles: AxisTitles(
                                                            sideTitles: SideTitles(
                                                              showTitles: true,
                                                              reservedSize: 40,
                                                              getTitlesWidget: (value, meta) {
                                                                final index = value.toInt();
                                                                if (index >= 0 && index < bookingData.length) {
                                                                  return SideTitleWidget(
                                                                    meta: meta,
                                                                    space: 8,
                                                                    child: Text(
                                                                      bookingData[index].category,
                                                                      style: const TextStyle(fontFamily: 'Open Sans', fontSize: 12, color: Color(0xFF131010)),
                                                                      textAlign: TextAlign.center,
                                                                    ),
                                                                  );
                                                                }
                                                                return const SizedBox();
                                                              },
                                                            ),
                                                          ),
                                                          leftTitles: AxisTitles(
                                                            sideTitles: SideTitles(
                                                              showTitles: true,
                                                              reservedSize: 40,
                                                              getTitlesWidget: (value, meta) {
                                                                return Text(
                                                                  value.toInt().toString(),
                                                                  style: const TextStyle(fontFamily: 'Open Sans', fontSize: 12, color: Color(0xFF131010)),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                                        ),
                                                        borderData: FlBorderData(show: false),
                                                        gridData: const FlGridData(show: false),
                                                      ),
                                                      swapAnimationDuration: const Duration(milliseconds: 800),
                                                      swapAnimationCurve: Curves.easeOut,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text(
                                              'Business Details',
                                              style: TextStyle(
                                                fontFamily: 'Montserrat',
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF131010),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.edit, color: Color(0xFF00C4B4)),
                                              onPressed: () {
                                                setState(() => isEditingServiceDetails = true);
                                                _showServiceDetailsModal();
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Card(
                                          elevation: 6,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          child: Container(
                                            padding: const EdgeInsets.all(16.0),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [const Color(0xFFF5FBFF), const Color(0xFFE8F4FA)],
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                _buildProfileField('Business Name', serviceProviderDetails?['businessName']?.toString() ?? 'Not set'),
                                                const SizedBox(height: 12),
                                                _buildProfileField('Services', serviceProviderDetails?['category']?.toString() ?? 'Not set'),
                                                const SizedBox(height: 12),
                                                _buildProfileField('Address', serviceProviderDetails?['location']?.toString() ?? 'Not set'),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 32),
                                        const Text(
                                          'My Services',
                                          style: TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF131010),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Card(
                                          elevation: 6,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          child: Column(
                                            children: [
                                              Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [const Color(0xFFF5FBFF), const Color(0xFFE8F4FA)],
                                                  ),
                                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                                                ),
                                                child: TabBar(
                                                  controller: _tabController,
                                                  labelColor: const Color(0xFF00C4B4),
                                                  unselectedLabelColor: Colors.grey,
                                                  indicator: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: [const Color(0xFF00C4B4).withOpacity(0.8), Colors.tealAccent.withOpacity(0.8)],
                                                    ),
                                                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
                                                  ),
                                                  tabs: const [
                                                    Tab(text: 'Ongoing'),
                                                    Tab(text: 'Completed'),
                                                    Tab(text: 'Cancelled'),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(
                                                height: 300,
                                                child: TabBarView(
                                                  controller: _tabController,
                                                  children: [
                                                    _buildBookingList(ongoingBookings, true),
                                                    _buildBookingList(completedBookings, false),
                                                    _buildBookingList(cancelledBookings, false),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (role != 'service_provider') ...[
                                        const SizedBox(height: 32),
                                        const Text(
                                          'Service Provider Status',
                                          style: TextStyle(
                                            fontFamily: 'Montserrat',
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF131010),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Card(
                                          elevation: 6,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          child: Container(
                                            padding: const EdgeInsets.all(16.0),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [const Color(0xFFF5FBFF), const Color(0xFFE8F4FA)],
                                              ),
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: Column(
                                              children: [
                                                const Text(
                                                  'You are currently a customer. Register as a service provider to offer your services.',
                                                  style: TextStyle(fontFamily: 'Open Sans', fontSize: 16, color: Color(0xFF131010)),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 20),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(builder: (context) => const ServiceProviderRegistrationScreen()),
                                                    );
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF00C4B4),
                                                    foregroundColor: Colors.white,
                                                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                    elevation: 4,
                                                  ),
                                                  child: const Text(
                                                    'Register as Service Provider',
                                                    style: TextStyle(fontFamily: 'Montserrat', fontSize: 16, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 32),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        );
      },
    );
  }
}