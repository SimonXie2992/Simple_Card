import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/card_organization.dart';
import 'card_edit_screen.dart';
import '../state/card_store.dart';

class CardDetailScreen extends StatefulWidget {
  final BusinessCard card;

  const CardDetailScreen({super.key, required this.card});

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  late BusinessCard card;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    card = widget.card;
  }

  // ==== Actions ====

  Future<void> _makeCall(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _sendEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openMap(String address) async {
    final uri = Uri.parse('https://maps.apple.com/?q=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openUrl(String url) async {
    final fullUrl = url.startsWith('http') ? url : 'https://$url';
    final uri = Uri.parse(fullUrl);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _shareCard(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null) {
      Share.share(
        card.toContactText(),
        sharePositionOrigin: box.localToGlobal(Offset.zero) & box.size,
      );
    } else {
      Share.share(card.toContactText());
    }
  }

  void _copyCard() {
    Clipboard.setData(ClipboardData(text: card.toContactText()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact info copied to clipboard'), backgroundColor: Color(0xFF34C759), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _toggleFavorite() async {
    final updated = await appCardStore.toggleFavorite(card.id);
    if (updated == null || !mounted) {
      return;
    }
    setState(() { card = updated; });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(card.isFavorite ? 'Added to favorites' : 'Removed from favorites'), backgroundColor: const Color(0xFF007AFF), duration: const Duration(seconds: 1)),
    );
  }

  void _deleteCard() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: Text('Are you sure you want to delete ${card.name}\'s card?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await appCardStore.deleteCard(card.id);
              if (!mounted) {
                return;
              }
              Navigator.pop(context, 'deleted');
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFFF3B30))),
          ),
        ],
      ),
    );
  }

  void _showQRCode() {
    final qrData = 'BEGIN:VCARD\nVERSION:3.0\nFN:${card.name}\nORG:${card.company ?? ""}\nTITLE:${card.title ?? ""}\nTEL:${card.displayPhone ?? ""}\nEMAIL:${card.email ?? ""}\nEND:VCARD';
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(card.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              QrImageView(data: qrData, version: QrVersions.auto, size: 200, gapless: true,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Color(0xFF007AFF)),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Color(0xFF1C1C1E)),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Color(0xFF007AFF)))),
            ],
          ),
        ),
      ),
    );
  }

  void _editCard() async {
    final result = await Navigator.of(context).push<BusinessCard>(
      MaterialPageRoute(builder: (_) => CardEditScreen(card: card)),
    );
    if (result != null) {
      final saved = await appCardStore.upsertCard(result);
      if (!mounted) {
        return;
      }
      setState(() { card = saved; });
    }
  }

  void _showFullScreenImage() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: card.imageUrls.isNotEmpty
                  ? Image.network(card.imageUrls[_currentImageIndex], fit: BoxFit.contain)
                  : Container(
                      width: double.infinity,
                      height: 300,
                      color: const Color(0xFFF2F2F7),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.credit_card, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(card.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                          Text(card.title ?? '', style: TextStyle(color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
            ),
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==== Build UI ====

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Card Details', style: TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(card.isFavorite ? Icons.star : Icons.star_outline, color: card.isFavorite ? Colors.amber : Colors.grey),
            onPressed: _toggleFavorite,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Colors.black87),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              switch (value) {
                case 'edit': _editCard(); break;
                // Share from popup menu might not have specific origin in this context, use default
                case 'share': Share.share(card.toContactText()); break;
                case 'qr': _showQRCode(); break;
                case 'copy': _copyCard(); break;
                case 'delete': _deleteCard(); break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 18, color: Color(0xFF007AFF)), SizedBox(width: 10), Text('Edit')])),
              const PopupMenuItem(value: 'share', child: Row(children: [Icon(Icons.share_outlined, size: 18, color: Color(0xFF007AFF)), SizedBox(width: 10), Text('Share')])),
              const PopupMenuItem(value: 'qr', child: Row(children: [Icon(Icons.qr_code, size: 18, color: Color(0xFF007AFF)), SizedBox(width: 10), Text('QR Code')])),
              const PopupMenuItem(value: 'copy', child: Row(children: [Icon(Icons.copy_outlined, size: 18, color: Color(0xFF007AFF)), SizedBox(width: 10), Text('Copy')])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Color(0xFFFF3B30)), SizedBox(width: 10), Text('Delete', style: TextStyle(color: Color(0xFFFF3B30)))])),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardImage(),
            _buildContactCard(),
            _buildQuickActions(),
            _buildContactDetails(),
            if (card.notes != null && card.notes!.isNotEmpty) _buildNotesSection(),
            if (card.socialAccounts.isNotEmpty) _buildSocialSection(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildCardImage() {
    return GestureDetector(
      onTap: _showFullScreenImage,
      child: Container(
        margin: const EdgeInsets.all(20),
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: card.imageUrls.isNotEmpty
                  ? PageView.builder(
                      itemCount: card.imageUrls.length,
                      onPageChanged: (i) => setState(() => _currentImageIndex = i),
                      itemBuilder: (_, i) => Image.network(card.imageUrls[i], fit: BoxFit.cover, width: double.infinity),
                    )
                  : Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF007AFF).withValues(alpha: 0.05), const Color(0xFF5856D6).withValues(alpha: 0.05)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.credit_card, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text('Original Card Image', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
                          const SizedBox(height: 4),
                          Text('Tap to view full screen', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
            ),
            if (card.imageUrls.length > 1)
              Positioned(
                bottom: 8,
                left: 0, right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(card.imageUrls.length, (i) =>
                    Container(
                      width: 6, height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _currentImageIndex ? const Color(0xFF007AFF) : Colors.grey.shade300,
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              top: 8, right: 8,
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), shape: BoxShape.circle),
                child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF007AFF), Color(0xFF5856D6)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(child: Text(card.name[0], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                if (card.title != null) ...[
                  const SizedBox(height: 2),
                  Text(card.title!, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                ],
                if (card.company != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    [card.company, card.department].where((s) => s != null && s.isNotEmpty).join(' • '),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(child: _buildActionButton(Icons.phone, 'Call', const Color(0xFF34C759), card.displayPhone != null, (_) { if (card.displayPhone != null) _makeCall(card.displayPhone!); })),
          const SizedBox(width: 10),
          Expanded(child: _buildActionButton(Icons.email, 'Email', const Color(0xFF007AFF), card.email != null, (_) { if (card.email != null) _sendEmail(card.email!); })),
          const SizedBox(width: 10),
          Expanded(child: _buildActionButton(Icons.share, 'Share', const Color(0xFF5856D6), true, (ctx) => _shareCard(ctx))),
          const SizedBox(width: 10),
          Expanded(child: _buildActionButton(Icons.edit, 'Edit', const Color(0xFFFF9500), true, (_) => _editCard())),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color, bool enabled, void Function(BuildContext)? onTap) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: enabled && onTap != null ? () => onTap(context) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: enabled ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: enabled ? color : Colors.grey.shade400, size: 22),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: enabled ? color : Colors.grey.shade400)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactDetails() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contact Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 16),
          if (card.tel != null) _buildContactRow(Icons.phone_outlined, 'TEL', card.tel!, () => _makeCall(card.tel!)),
          if (card.mobile != null) _buildContactRow(Icons.smartphone_outlined, 'Mobile', card.mobile!, () => _makeCall(card.mobile!)),
          if (card.phone != null && card.phone != card.tel && card.phone != card.mobile)
            _buildContactRow(Icons.phone_outlined, 'Phone', card.phone!, () => _makeCall(card.phone!)),
          if (card.fax != null) _buildContactRow(Icons.fax_outlined, 'Fax', card.fax!, () => _makeCall(card.fax!)),
          if (card.email != null) _buildContactRow(Icons.email_outlined, 'Email', card.email!, () => _sendEmail(card.email!)),
          if (card.company != null) _buildContactRow(Icons.business_outlined, 'Company', card.company!, null),
          if (card.department != null) _buildContactRow(Icons.account_tree_outlined, 'Department', card.department!, null),
          if (card.title != null) _buildContactRow(Icons.work_outline, 'Title', card.title!, null),
          if (card.address != null) _buildContactRow(Icons.location_on_outlined, 'Address', card.address!, () => _openMap(card.address!)),
          if (card.website != null) _buildContactRow(Icons.language_outlined, 'Website', card.website!, () => _openUrl(card.website!)),
        ],
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value, VoidCallback? onTap) {
    final widget = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF007AFF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontSize: 15, color: onTap != null ? const Color(0xFF007AFF) : Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: widget);
    }
    return widget;
  }

  Widget _buildNotesSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
              GestureDetector(
                onTap: _editCard,
                child: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF007AFF)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(card.notes!, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildSocialSection() {
    final socialIcons = {
      'whatsapp': Icons.chat_outlined,
      'linkedin': Icons.work_outlined,
      'line': Icons.chat_bubble_outlined,
      'wechat': Icons.message_outlined,
      'qq': Icons.forum_outlined,
      'facebook': Icons.facebook_outlined,
      'instagram': Icons.photo_camera_outlined,
      'twitter': Icons.alternate_email,
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Social', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 12),
          ...card.socialAccounts.entries.map((e) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(socialIcons[e.key] ?? Icons.link, size: 20, color: const Color(0xFF007AFF)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.key[0].toUpperCase() + e.key.substring(1), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                      Text(e.value, style: const TextStyle(fontSize: 14, color: Color(0xFF007AFF))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
