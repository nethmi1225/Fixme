import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://192.168.90.237:5000'; // Update this for production

  Future<List<Map<String, dynamic>>> getRecommendations({
    required String userId,
    String? category,
    int topN = 3,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/recommendations'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'category': category,
          'top_n': topN,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['recommendations']);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to fetch recommendations');
      }
    } catch (e) {
      throw Exception('Error fetching recommendations: $e');
    }
  }
}