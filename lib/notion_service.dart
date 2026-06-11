class NotionService {
  const NotionService();

  bool get isConfigured => false;

  Future<void> createBusinessCard({
    required String name,
    required String company,
    required String title,
    String? mobile,
    String? landline,
    String? email,
    List<String> tags = const [],
  }) async {
    throw StateError(
      'Notion sync is disabled. Configure a secure runtime secret provider before enabling network sync.',
    );
  }
}
