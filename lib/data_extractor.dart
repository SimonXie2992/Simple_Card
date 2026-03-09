import 'dart:core';

class DataExtractor {
  static Map<String, String> extractEnglishInfo(String rawText) {
    String name = "";
    String company = "";
    String title = "";
    String phone = "";
    String email = "";

    List<String> lines = rawText.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    RegExp emailRegex = RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
    RegExp phoneRegex = RegExp(r'(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4,8}');

    for (String line in lines) {
      if (email.isEmpty && emailRegex.hasMatch(line)) {
        email = emailRegex.stringMatch(line) ?? "";
      } else if (phone.isEmpty && phoneRegex.hasMatch(line)) {
        phone = phoneRegex.stringMatch(line) ?? "";
      }
    }

    if (lines.isNotEmpty) name = lines[0];
    if (lines.length > 1) {
      if (lines[1].toLowerCase().contains('director') || 
          lines[1].toLowerCase().contains('manager') || 
          lines[1].toLowerCase().contains('vp')) {
        title = lines[1];
        if (lines.length > 2) company = lines[2];
      } else {
        company = lines[1];
        if (lines.length > 2) title = lines[2];
      }
    }

    return {
      "name": name,
      "company": company,
      "title": title,
      "mobile": phone,
      "email": email,
    };
  }
}
