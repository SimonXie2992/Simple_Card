import 'package:flutter/foundation.dart';

import '../models/card_organization.dart';
import '../repositories/card_repository.dart';
import '../repositories/local_card_repository.dart';

class CardStore extends ChangeNotifier {
  CardStore(this._repository);

  final CardRepository _repository;
  final List<BusinessCard> _cards = <BusinessCard>[];

  bool _isLoaded = false;
  bool _isLoading = false;
  Object? _lastError;

  List<BusinessCard> get cards => List<BusinessCard>.unmodifiable(_cards);
  bool get isLoaded => _isLoaded;
  bool get isLoading => _isLoading;
  Object? get lastError => _lastError;

  Future<void> ensureLoaded() async {
    if (_isLoaded || _isLoading) {
      return;
    }
    await reload();
  }

  Future<void> reload() async {
    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final loaded = await _repository.loadCards();
      _cards
        ..clear()
        ..addAll(loaded);
      _isLoaded = true;
    } catch (error) {
      _lastError = error;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<BusinessCard> upsertCard(BusinessCard card) async {
    final saved = await _repository.upsertCard(card);
    final index = _cards.indexWhere((item) => item.id == saved.id);
    if (index >= 0) {
      _cards[index] = saved;
    } else {
      _cards.insert(0, saved);
    }
    _cards.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    _isLoaded = true;
    notifyListeners();
    return saved;
  }

  Future<void> deleteCard(String id) async {
    await _repository.deleteCard(id);
    _cards.removeWhere((card) => card.id == id);
    notifyListeners();
  }

  Future<BusinessCard?> toggleFavorite(String id) async {
    final updated = await _repository.toggleFavorite(id);
    if (updated == null) {
      return null;
    }

    final index = _cards.indexWhere((card) => card.id == id);
    if (index >= 0) {
      _cards[index] = updated;
    }
    notifyListeners();
    return updated;
  }

  Future<void> clearCards() async {
    await _repository.clearCards();
    _cards.clear();
    _isLoaded = true;
    notifyListeners();
  }

  Future<List<BusinessCard>> searchCards(String query) async {
    await ensureLoaded();
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return cards;
    }

    return _cards.where((card) {
      final fields = <String?>[
        card.name,
        card.company,
        card.department,
        card.title,
        card.mobile,
        card.phone,
        card.tel,
        card.fax,
        card.email,
        card.website,
        card.address,
        card.notes,
      ];
      return fields.any((field) => field?.toLowerCase().contains(normalized) ?? false);
    }).toList(growable: false);
  }
}

final CardStore appCardStore = CardStore(LocalCardRepository());
