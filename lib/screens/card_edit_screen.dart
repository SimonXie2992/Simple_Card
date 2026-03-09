import 'package:flutter/material.dart';
import '../models/card_organization.dart';

class CardEditScreen extends StatefulWidget {
  final BusinessCard card;

  const CardEditScreen({super.key, required this.card});

  @override
  State<CardEditScreen> createState() => _CardEditScreenState();
}

class _CardEditScreenState extends State<CardEditScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _companyCtrl;
  late TextEditingController _departmentCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _telCtrl;
  late TextEditingController _mobileCtrl;
  late TextEditingController _faxCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _notesCtrl;

  // Social
  late TextEditingController _whatsappCtrl;
  late TextEditingController _linkedinCtrl;
  late TextEditingController _lineCtrl;
  late TextEditingController _wechatCtrl;
  late TextEditingController _qqCtrl;
  late TextEditingController _facebookCtrl;
  late TextEditingController _instagramCtrl;
  late TextEditingController _twitterCtrl;

  @override
  void initState() {
    super.initState();
    final c = widget.card;
    _nameCtrl = TextEditingController(text: c.name);
    _companyCtrl = TextEditingController(text: c.company ?? '');
    _departmentCtrl = TextEditingController(text: c.department ?? '');
    _titleCtrl = TextEditingController(text: c.title ?? '');
    _telCtrl = TextEditingController(text: c.tel ?? '');
    _mobileCtrl = TextEditingController(text: c.mobile ?? '');
    _faxCtrl = TextEditingController(text: c.fax ?? '');
    _emailCtrl = TextEditingController(text: c.email ?? '');
    _addressCtrl = TextEditingController(text: c.address ?? '');
    _websiteCtrl = TextEditingController(text: c.website ?? '');
    _notesCtrl = TextEditingController(text: c.notes ?? '');

    final s = c.socialAccounts;
    _whatsappCtrl = TextEditingController(text: s['whatsapp'] ?? '');
    _linkedinCtrl = TextEditingController(text: s['linkedin'] ?? '');
    _lineCtrl = TextEditingController(text: s['line'] ?? '');
    _wechatCtrl = TextEditingController(text: s['wechat'] ?? '');
    _qqCtrl = TextEditingController(text: s['qq'] ?? '');
    _facebookCtrl = TextEditingController(text: s['facebook'] ?? '');
    _instagramCtrl = TextEditingController(text: s['instagram'] ?? '');
    _twitterCtrl = TextEditingController(text: s['twitter'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _companyCtrl.dispose(); _departmentCtrl.dispose();
    _titleCtrl.dispose(); _telCtrl.dispose(); _mobileCtrl.dispose();
    _faxCtrl.dispose(); _emailCtrl.dispose(); _addressCtrl.dispose();
    _websiteCtrl.dispose(); _notesCtrl.dispose();
    _whatsappCtrl.dispose(); _linkedinCtrl.dispose(); _lineCtrl.dispose();
    _wechatCtrl.dispose(); _qqCtrl.dispose(); _facebookCtrl.dispose();
    _instagramCtrl.dispose(); _twitterCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final social = <String, String>{};
    if (_whatsappCtrl.text.isNotEmpty) social['whatsapp'] = _whatsappCtrl.text;
    if (_linkedinCtrl.text.isNotEmpty) social['linkedin'] = _linkedinCtrl.text;
    if (_lineCtrl.text.isNotEmpty) social['line'] = _lineCtrl.text;
    if (_wechatCtrl.text.isNotEmpty) social['wechat'] = _wechatCtrl.text;
    if (_qqCtrl.text.isNotEmpty) social['qq'] = _qqCtrl.text;
    if (_facebookCtrl.text.isNotEmpty) social['facebook'] = _facebookCtrl.text;
    if (_instagramCtrl.text.isNotEmpty) social['instagram'] = _instagramCtrl.text;
    if (_twitterCtrl.text.isNotEmpty) social['twitter'] = _twitterCtrl.text;

    final updated = widget.card.copyWith(
      name: _nameCtrl.text,
      company: _companyCtrl.text.isNotEmpty ? _companyCtrl.text : null,
      department: _departmentCtrl.text.isNotEmpty ? _departmentCtrl.text : null,
      title: _titleCtrl.text.isNotEmpty ? _titleCtrl.text : null,
      tel: _telCtrl.text.isNotEmpty ? _telCtrl.text : null,
      mobile: _mobileCtrl.text.isNotEmpty ? _mobileCtrl.text : null,
      fax: _faxCtrl.text.isNotEmpty ? _faxCtrl.text : null,
      email: _emailCtrl.text.isNotEmpty ? _emailCtrl.text : null,
      address: _addressCtrl.text.isNotEmpty ? _addressCtrl.text : null,
      website: _websiteCtrl.text.isNotEmpty ? _websiteCtrl.text : null,
      notes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      socialAccounts: social,
    );

    Navigator.pop(context, updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black87), onPressed: () => Navigator.pop(context)),
        title: const Text('Edit Card', style: TextStyle(color: Colors.black87, fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save', style: TextStyle(color: Color(0xFF007AFF), fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Basic Info'),
            _field('Name *', _nameCtrl, Icons.person_outline),
            _field('Company', _companyCtrl, Icons.business_outlined),
            _field('Department', _departmentCtrl, Icons.account_tree_outlined),
            _field('Title', _titleCtrl, Icons.work_outline),

            const SizedBox(height: 24),
            _sectionTitle('Contact'),
            _field('TEL', _telCtrl, Icons.phone_outlined, keyboard: TextInputType.phone),
            _field('Mobile', _mobileCtrl, Icons.smartphone_outlined, keyboard: TextInputType.phone),
            _field('Fax', _faxCtrl, Icons.fax_outlined, keyboard: TextInputType.phone),
            _field('Email', _emailCtrl, Icons.email_outlined, keyboard: TextInputType.emailAddress),
            _field('Address', _addressCtrl, Icons.location_on_outlined),
            _field('Website', _websiteCtrl, Icons.language_outlined, keyboard: TextInputType.url),

            const SizedBox(height: 24),
            _sectionTitle('Notes'),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _notesCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Add notes about this contact...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
            ),

            const SizedBox(height: 24),
            _sectionTitle('Social Accounts'),
            _field('WhatsApp', _whatsappCtrl, Icons.chat_outlined),
            _field('LinkedIn', _linkedinCtrl, Icons.work_outlined),
            _field('LINE', _lineCtrl, Icons.chat_bubble_outlined),
            _field('WeChat', _wechatCtrl, Icons.message_outlined),
            _field('QQ', _qqCtrl, Icons.forum_outlined),
            _field('Facebook', _facebookCtrl, Icons.facebook_outlined),
            _field('Instagram', _instagramCtrl, Icons.photo_camera_outlined),
            _field('Twitter / X', _twitterCtrl, Icons.alternate_email),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.5)),
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon, {TextInputType? keyboard}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          prefixIcon: Icon(icon, color: const Color(0xFF007AFF), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      ),
    );
  }
}
