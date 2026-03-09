import 'dart:convert';
import 'package:http/http.dart' as http;

class NotionService {
  static const String _baseUrl = 'https://api.notion.com/v1/pages';
  static const String _secret = 'YOUR_NOTION_SECRET'; // REPLACE THIS WITH YOUR NOTION SECRET
  static const String _databaseId = '2deaf405ab94808a80b4fa0c977cd9d2';

  Future<void> createBusinessCard({
    required String name,
    required String company,
    required String title,
    String? mobile,
    String? landline,
    String? email,
    List<String> tags = const [],
  }) async {
    try {
      final url = Uri.parse(_baseUrl);
      final body = {
        "parent": {"database_id": _databaseId},
        "properties": {
          "Name": {"title": [{"text": {"content": name}}]},
          "Company": {"select": {"name": company}},
          "Title": {"rich_text": [{"text": {"content": title}}]},
          "Mobile": {"phone_number": mobile},
          "Landline": {"phone_number": landline},
          "Email": {"email": email},
          "Tags": {"multi_select": tags.map((tag) => {"name": tag}).toList()}
        }
      };
      final response = await http.post(
        url,
        headers: {
          "Authorization": "Bearer $_secret",
          "Notion-Version": "2022-06-28",
          "Content-Type": "application/json",
        },
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        print("Sync Success: $name @ $company");
      } else {
        print("Sync Failed: ${response.statusCode}");
        throw Exception('Notion API Error');
      }
    } catch (e) {
      print("Error: $e");
      rethrow;
    }
  }
}
