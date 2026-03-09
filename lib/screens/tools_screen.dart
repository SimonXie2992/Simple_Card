import 'package:flutter/material.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 16, 0, 20),
              child: Text('Toolbox', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),

            // Management Tools
            _buildSectionTitle('Management Tools'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _buildToolItem(context, Icons.analytics_outlined, 'Card Analytics', 'View scanning statistics', const Color(0xFF5856D6)),
                  _buildDivider(),
                  _buildToolItem(context, Icons.qr_code_scanner, 'QR Code Scanner', 'Scan QR codes from cards', const Color(0xFF007AFF)),
                  _buildDivider(),
                  _buildToolItem(context, Icons.text_snippet_outlined, 'OCR Text Extract', 'Extract text from images', const Color(0xFF34C759)),
                  _buildDivider(),
                  _buildToolItem(context, Icons.find_replace_outlined, 'Duplicate Finder', 'Find and merge duplicate contacts', const Color(0xFFFF9500)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Backup & Sync
            _buildSectionTitle('Backup & Sync'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  _buildToolItem(context, Icons.cloud_upload_outlined, 'Backup to Cloud', 'Save your cards to iCloud', const Color(0xFF007AFF)),
                  _buildDivider(),
                  _buildToolItem(context, Icons.cloud_download_outlined, 'Restore from Cloud', 'Restore cards from backup', const Color(0xFF5856D6)),
                  _buildDivider(),
                  _buildToolItem(context, Icons.sync_outlined, 'Sync Settings', 'Configure auto-sync options', const Color(0xFF34C759)),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.5)),
    );
  }

  Widget _buildToolItem(BuildContext context, IconData icon, String title, String subtitle, Color color) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title — Coming soon'),
            backgroundColor: color,
            duration: const Duration(seconds: 1),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black87)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, indent: 68, color: Colors.grey.shade200);
  }
}
