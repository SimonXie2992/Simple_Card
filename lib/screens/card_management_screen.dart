import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/card_organization.dart';
import 'scanner_screen.dart';

class CardManagementScreen extends StatelessWidget {
  const CardManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: [
        const SizedBox(height: 8),
        _buildSection('Import', [
          _ManagementItem(Icons.camera_alt_outlined, 'Scan & Import', 'Auto-detect business cards or documents', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ScannerScreen()));
          }),
          _ManagementItem(Icons.photo_library_outlined, 'Import from Gallery', 'Import card images from photo library', () async {
            final ImagePicker picker = ImagePicker();
            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null && context.mounted) {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) => ScannerScreen(initialMode: 0, initialImagePath: image.path),
              ));
            }
          }),
          _ManagementItem(Icons.file_upload_outlined, 'Import from File', 'Import from CSV, vCard, or Excel', () {}),
        ]),
        const SizedBox(height: 16),
        _buildSection('Export', [
          _ManagementItem(Icons.file_download_outlined, 'Export as CSV', 'Export all cards as CSV file', () async {
            try {
              final docsDir = await getApplicationDocumentsDirectory();
              final file = File('${docsDir.path}/cards_export.csv');
              final buffer = StringBuffer();
              buffer.writeln('Name,Company,Title,Mobile,Email,Website,Address');
              
              String escape(String? s) => s == null ? '""' : '"${s.replaceAll('"', '""')}"';
              for (var card in MockData.recentCards) {
                buffer.writeln('${escape(card.name)},${escape(card.company)},${escape(card.title)},${escape(card.mobile)},${escape(card.email)},${escape(card.website)},${escape(card.address)}');
              }
              await file.writeAsString(buffer.toString());
              if (context.mounted) {
                Share.shareXFiles([XFile(file.path)], text: 'Exported Contacts CSV');
              }
            } catch (e) {
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
            }
          }),
          _ManagementItem(Icons.contact_mail_outlined, 'Export as vCard', 'Export all cards as vCard (.vcf)', () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exporting as vCard...'), backgroundColor: Color(0xFF007AFF)));
          }),
          _ManagementItem(Icons.table_chart_outlined, 'Export as Excel', 'Export all cards as Excel file', () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Exporting as Excel...'), backgroundColor: Color(0xFF007AFF)));
          }),
        ]),
        const SizedBox(height: 16),
        _buildSection('Batch Operations', [
          _ManagementItem(Icons.select_all_outlined, 'Batch Delete', 'Select and delete multiple cards', () {}),
          _ManagementItem(Icons.merge_outlined, 'Merge Contacts', 'Merge duplicate contacts', () {}),
          _ManagementItem(Icons.label_outlined, 'Batch Tag', 'Add tags to multiple cards', () {}),
        ]),
        const SizedBox(height: 16),
        _buildSection('Utilities', [
          _ManagementItem(Icons.find_replace_outlined, 'Find Duplicates', 'Detect and merge duplicate cards', () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanning for duplicates...'), backgroundColor: Color(0xFF007AFF)));
          }),
          _ManagementItem(Icons.cleaning_services_outlined, 'Clean Up', 'Remove empty or incomplete cards', () {}),
        ]),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSection(String title, List<_ManagementItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.5)),
        ),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: items.asMap().entries.map((entry) {
              final item = entry.value;
              final isLast = entry.key == items.length - 1;
              return Column(
                children: [
                  GestureDetector(
                    onTap: item.onTap,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(8)),
                            child: Icon(item.icon, color: const Color(0xFF007AFF), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                                Text(item.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast) Divider(height: 1, indent: 64, color: Colors.grey.shade200),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ManagementItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _ManagementItem(this.icon, this.title, this.subtitle, this.onTap);
}
