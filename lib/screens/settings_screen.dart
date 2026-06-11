import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            _buildProfileSection(context),
            const SizedBox(height: 24),

            // Preferences
            _buildSectionTitle('Preferences'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _buildSettingsItem(context, Icons.language, 'Language', 'English', const Color(0xFF007AFF), () => _showLanguagePicker(context)),
                  _buildDivider(),
                  _buildSettingsItem(context, Icons.dark_mode_outlined, 'Appearance', 'Light', const Color(0xFF5856D6), () => _showAppearancePicker(context)),
                  _buildDivider(),
                  _buildSettingsItem(context, Icons.notifications_outlined, 'Notifications', '', const Color(0xFFFF3B30), () => _showNotificationSettings(context)),
                  _buildDivider(),
                  _buildSettingsItem(context, Icons.credit_card_outlined, 'Default Card Style', 'Standard', const Color(0xFF34C759), () => _showCardStylePicker(context)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Data & Privacy
            _buildSectionTitle('Data & Privacy'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _buildSettingsItem(context, Icons.lock_outline, 'Privacy', '', const Color(0xFFFF9500), () => _showPrivacySettings(context)),
                  _buildDivider(),
                  _buildSettingsItem(context, Icons.storage_outlined, 'Storage', '', const Color(0xFF007AFF), () => _showStorageInfo(context)),
                  _buildDivider(),
                  _buildSettingsItem(context, Icons.delete_outline, 'Clear Data', '', const Color(0xFFFF3B30), () => _showClearDataConfirm(context)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Support
            _buildSectionTitle('Support'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _buildSettingsItem(context, Icons.help_outline, 'Help Center', '', const Color(0xFF007AFF), () => _showHelpCenter(context)),
                  _buildDivider(),
                  _buildSettingsItem(context, Icons.feedback_outlined, 'Send Feedback', '', const Color(0xFF34C759), () => _showFeedbackDialog(context)),
                  _buildDivider(),
                  _buildSettingsItem(context, Icons.info_outline, 'About', 'v1.0.0', const Color(0xFF8E8E93), () => _showAboutDialog(context)),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF007AFF), Color(0xFF5856D6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(child: Text('S', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Simon Xie', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text('simon@toppan.com', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _showProfileEdit(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_outlined, color: Color(0xFF007AFF), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.5)),
    );
  }

  Widget _buildSettingsItem(BuildContext context, IconData icon, String title, String value, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87))),
            if (value.isNotEmpty) Text(value, style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 62, color: Colors.grey.shade200);
  }

  // ==== Dialog Handlers ====

  void _showProfileEdit(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _editField('Name', 'Simon Xie'),
            _editField('Email', 'simon@toppan.com'),
            _editField('Company', 'TOPPAN Group'),
            _editField('Title', 'Sales Director'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007AFF), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: TextEditingController(text: value),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          filled: true,
          fillColor: const Color(0xFFF8F9FA),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    _showOptionPicker(context, 'Language', ['English', '中文', '日本語', '한국어']);
  }

  void _showAppearancePicker(BuildContext context) {
    _showOptionPicker(context, 'Appearance', ['Light', 'Dark', 'System']);
  }

  void _showCardStylePicker(BuildContext context) {
    _showOptionPicker(context, 'Default Card Style', ['Standard', 'Compact', 'Detailed']);
  }

  void _showOptionPicker(BuildContext context, String title, List<String> options) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...options.map((opt) => ListTile(
              title: Text(opt),
              trailing: opt == options[0] ? const Icon(Icons.check, color: Color(0xFF007AFF)) : null,
              onTap: () => Navigator.pop(context),
            )),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SwitchListTile(title: const Text('Push Notifications'), value: true, onChanged: (v) {}, activeThumbColor: const Color(0xFF007AFF)),
            SwitchListTile(title: const Text('Scan Reminders'), value: false, onChanged: (v) {}, activeThumbColor: const Color(0xFF007AFF)),
            SwitchListTile(title: const Text('Backup Alerts'), value: true, onChanged: (v) {}, activeThumbColor: const Color(0xFF007AFF)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showPrivacySettings(BuildContext context) {
    _showInfoDialog(context, 'Privacy', 'Your data is stored locally on your device. No personal data is sent to external servers without your consent.');
  }

  void _showStorageInfo(BuildContext context) {
    _showInfoDialog(context, 'Storage', 'Cards: 5 items (0.2 MB)\nImages: 0 items (0 MB)\nTotal: 0.2 MB');
  }

  void _showClearDataConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Data'),
        content: const Text('This will delete all scanned cards and settings. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data cleared'), backgroundColor: Color(0xFFFF3B30)));
            },
            child: const Text('Clear', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
  }

  void _showHelpCenter(BuildContext context) {
    _showInfoDialog(context, 'Help Center', '• Scan cards using the camera button\n• View cards in the Card Holder tab\n• Use Toolbox for management features\n• Contact support at help@toppan.com');
  }

  void _showFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback'),
        content: TextField(
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Tell us what you think...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you for your feedback!'), backgroundColor: Color(0xFF34C759)));
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    _showInfoDialog(context, 'About', 'Simple Card v1.0.0\n\n© 2024 TOPPAN Group\nDeveloped by Simon Xie\n\nA smart business card scanner and organizer.');
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: Color(0xFF007AFF)))),
        ],
      ),
    );
  }
}
