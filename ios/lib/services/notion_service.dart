import 'dart:convert';
import 'package:http/http.dart' as http;

class NotionService {
  final String _baseUrl = 'https://api.notion.com/v1';
  final String _token = 'YOUR_NOTION_INTERNAL_INTEGRATION_TOKEN';
  final String _databaseId = 'YOUR_DATABASE_ID';

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $_token',
    'Notion-Version': '2022-06-28',
    'Content-Type': 'application/json',
  };

  Future<List<dynamic>> fetchNetworkingContacts() async {
    final url = Uri.parse('$_baseUrl/databases/$_databaseId/query');
    try {
      final response = await http.post(url, headers: _headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['results'] as List<dynamic>;
      } else {
        throw Exception('Notion API Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network Injection Failure: $e');
    }
  }

  Future<void> syncNewContact(Map<String, dynamic> contactData) async {
    final url = Uri.parse('$_baseUrl/pages');
    final body = jsonEncode({
      'parent': {'database_id': _databaseId},
      'properties': contactData,
    });

    try {
      final response = await http.post(url, headers: _headers, body: body);
      if (response.statusCode != 200) {
        throw Exception('Sync Failure: ${response.body}');
      }
    } catch (e) {
      throw Exception('Physical Write Error: $e');
    }
  }
}
