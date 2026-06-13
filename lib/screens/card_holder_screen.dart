import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'scanner_screen.dart';
import '../models/card_organization.dart';
import 'card_detail_screen.dart';
import 'card_management_screen.dart';
import '../state/card_store.dart';

class CardHolderScreen extends StatefulWidget {
  const CardHolderScreen({super.key});

  @override
  State<CardHolderScreen> createState() => _CardHolderScreenState();
}

class _CardHolderScreenState extends State<CardHolderScreen> {
  int _selectedTab = 0;
  final TextEditingController _searchController = TextEditingController();
  final List<BusinessCard> _allCards = <BusinessCard>[];
  List<BusinessCard> _filteredCards = <BusinessCard>[];

  @override
  void initState() {
    super.initState();
    appCardStore.addListener(_handleCardStoreChanged);
    _loadCardsFromRepository();
  }

  @override
  void dispose() {
    appCardStore.removeListener(_handleCardStoreChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCardsFromRepository() async {
    await appCardStore.ensureLoaded();
    _syncCardsFromStore();
  }

  void _handleCardStoreChanged() {
    if (!mounted) {
      return;
    }
    _syncCardsFromStore();
  }

  void _syncCardsFromStore() {
    setState(() {
      _allCards
        ..clear()
        ..addAll(appCardStore.cards);
      _performSearch(_searchController.text, notify: false);
    });
  }

  void _performSearch(String query, {bool notify = true}) {
    void applyFilter() {
      if (query.trim().isEmpty) {
        _filteredCards = List<BusinessCard>.from(_allCards);
      } else {
        final lower = query.trim().toLowerCase();
        _filteredCards = _allCards.where((card) {
          return card.name.toLowerCase().contains(lower) ||
              (card.company?.toLowerCase().contains(lower) ?? false) ||
              (card.title?.toLowerCase().contains(lower) ?? false) ||
              (card.mobile?.toLowerCase().contains(lower) ?? false) ||
              (card.phone?.toLowerCase().contains(lower) ?? false) ||
              (card.tel?.toLowerCase().contains(lower) ?? false) ||
              (card.email?.toLowerCase().contains(lower) ?? false);
        }).toList();
      }
    }

    if (notify) {
      setState(applyFilter);
    } else {
      applyFilter();
    }
  }

  void _showAddCardDialog() {
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
            const Text('Add Card', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _buildAddOption(Icons.camera_alt_outlined, 'Scan Business Card', 'Use camera to scan a card', () {
              Navigator.pop(context);
              // Navigate to scanner - handled by main.dart
            }),
            _buildAddOption(Icons.edit_outlined, 'Enter Manually', 'Type contact information', () {
              Navigator.pop(context);
              _addCardManually();
            }),
            _buildAddOption(Icons.photo_library_outlined, 'Import from Gallery', 'Select card image from gallery', () async {
              final navigator = Navigator.of(context);
              navigator.pop();
              final ImagePicker picker = ImagePicker();
              final XFile? image = await picker.pickImage(source: ImageSource.gallery);
              if (image == null || !mounted) {
                return;
              }
              navigator.push(
                MaterialPageRoute(
                  builder: (context) => ScannerScreen(initialMode: 0, initialImagePath: image.path),
                ),
              );
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOption(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0xFFF8F9FA), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: const Color(0xFF007AFF), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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

  void _addCardManually() {
    // For now, show a dialog to add basic info
    final nameCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Card'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *')),
              TextField(controller: companyCtrl, decoration: const InputDecoration(labelText: 'Company')),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                setState(() {
                  _allCards.insert(0, BusinessCard(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameCtrl.text,
                    company: companyCtrl.text.isNotEmpty ? companyCtrl.text : null,
                    phone: phoneCtrl.text.isNotEmpty ? phoneCtrl.text : null,
                    email: emailCtrl.text.isNotEmpty ? emailCtrl.text : null,
                  ));
                  _filteredCards = List.from(_allCards);
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions() {
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
            _buildMenuOption(Icons.sort, 'Sort by Name', () { Navigator.pop(context); _sortCards('name'); }),
            _buildMenuOption(Icons.business, 'Sort by Company', () { Navigator.pop(context); _sortCards('company'); }),
            _buildMenuOption(Icons.access_time, 'Sort by Date', () { Navigator.pop(context); _sortCards('date'); }),
            _buildMenuOption(Icons.select_all, 'Select All', () { Navigator.pop(context); }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF007AFF), size: 22),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _sortCards(String by) {
    setState(() {
      switch (by) {
        case 'name':
          _filteredCards.sort((a, b) => a.name.compareTo(b.name));
          break;
        case 'company':
          _filteredCards.sort((a, b) => (a.company ?? '').compareTo(b.company ?? ''));
          break;
        case 'date':
          _filteredCards.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
      }
    });
  }

  Future<void> _toggleFavorite(BusinessCard card) async {
    final updated = await appCardStore.toggleFavorite(card.id);
    if (updated == null || !mounted) {
      return;
    }
    _syncCardsFromStore();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            Expanded(child: _buildContent()),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _showAddCardDialog,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: const Color(0xFF007AFF), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
          const Text('Business Card Holder', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87)),
          GestureDetector(
            onTap: _showMoreOptions,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: const Color(0xFF007AFF), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.more_horiz, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _performSearch,
          decoration: InputDecoration(
            hintText: 'Search cards...',
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(icon: Icon(Icons.clear, color: Colors.grey.shade400, size: 18), onPressed: () { _searchController.clear(); _performSearch(''); })
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case 0: return _buildAllCards();
      case 1: return _buildGroups();
      case 2: return _buildFavorites();
      case 3: return _buildManagement();
      default: return _buildAllCards();
    }
  }

  // ==== TAB 0: All Cards ====
  Widget _buildAllCards() {
    final cards = _filteredCards;
    if (cards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No cards found', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
          ],
        ),
      );
    }

    // Sort by first letter
    cards.sort((a, b) => a.name.compareTo(b.name));
    final Map<String, List<BusinessCard>> grouped = {};
    for (var c in cards) {
      final letter = c.name[0].toUpperCase();
      grouped.putIfAbsent(letter, () => []).add(c);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: grouped.entries.map((e) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(e.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
            ),
            ...e.value.map((card) => _buildCardItem(card)),
          ],
        );
      }).toList(),
    );
  }

  // ==== TAB 1: Groups (by company) ====
  Widget _buildGroups() {
    final Map<String, List<BusinessCard>> byCompany = {};
    for (var c in _allCards) {
      final comp = c.company ?? 'Unknown';
      byCompany.putIfAbsent(comp, () => []).add(c);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: byCompany.entries.map((e) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
          child: ExpansionTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Icon(Icons.business, color: Color(0xFF007AFF), size: 20)),
            ),
            title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: Text('${e.value.length} card${e.value.length > 1 ? "s" : ""}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            children: e.value.map((card) => _buildCardItem(card, inGroup: true)).toList(),
          ),
        );
      }).toList(),
    );
  }

  // ==== TAB 2: Favorites ====
  Widget _buildFavorites() {
    final favCards = _allCards.where((c) => c.isFavorite).toList();
    if (favCards.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline, size: 56, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No favorites yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Tap ☆ on a card to add it here', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      children: favCards.map((card) => _buildCardItem(card)).toList(),
    );
  }

  // ==== TAB 3: Management ====
  Widget _buildManagement() {
    return const CardManagementScreen();
  }

  // ==== Card List Item ====
  Widget _buildCardItem(BusinessCard card, {bool inGroup = false}) {
    return GestureDetector(
      onTap: () async {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CardDetailScreen(card: card)));
      await appCardStore.reload();
    },
      child: Container(
        margin: EdgeInsets.only(bottom: 8, left: inGroup ? 8 : 0, right: inGroup ? 8 : 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: inGroup ? const Color(0xFFF8F9FA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: inGroup ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: const Color(0xFFE8F0FE), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(card.name[0], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF007AFF)))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(card.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(
                    [card.company, card.department].where((s) => s != null && s.isNotEmpty).join(' • '),
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _toggleFavorite(card),
              child: Icon(
                card.isFavorite ? Icons.star : Icons.star_outline,
                color: card.isFavorite ? Colors.amber : Colors.grey.shade400,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(0, Icons.credit_card_outlined, 'All Cards'),
          _buildNavItem(1, Icons.folder_outlined, 'Groups'),
          _buildNavItem(2, Icons.star_outline, 'Favorites'),
          _buildNavItem(3, Icons.widgets_outlined, 'Management'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? const Color(0xFF007AFF) : Colors.grey.shade400, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: isSelected ? const Color(0xFF007AFF) : Colors.grey.shade400, fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
        ],
      ),
    );
  }
}
