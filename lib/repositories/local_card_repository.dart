import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/card_organization.dart';
import 'card_repository.dart';

class LocalCardRepository implements CardRepository {
  LocalCardRepository({String fileName = 'simple_card_cards.json'})
      : _fileName = fileName;

  final String _fileName;

  Future<File> _file() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<List<BusinessCard>> _readAll() async {
    final file = await _file();
    if (!await file.exists()) {
      return <BusinessCard>[];
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <BusinessCard>[];
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException('Card repository JSON root must be a list.');
    }

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(BusinessCard.fromJson)
        .toList(growable: true);
  }

  Future<void> _writeAll(List<BusinessCard> cards) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final encoded = const JsonEncoder.withIndent('  ')
        .convert(cards.map((card) => card.toJson()).toList());
    await file.writeAsString(encoded);
  }

  @override
  Future<List<BusinessCard>> loadCards() async {
    final cards = await _readAll();
    cards.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return cards;
  }

  @override
  Future<BusinessCard> upsertCard(BusinessCard card) async {
    final cards = await _readAll();
    final index = cards.indexWhere((item) => item.id == card.id);

    if (index >= 0) {
      cards[index] = card;
    } else {
      cards.add(card);
    }

    await _writeAll(cards);
    return card;
  }

  @override
  Future<BusinessCard?> getCardById(String id) async {
    final cards = await _readAll();
    for (final card in cards) {
      if (card.id == id) {
        return card;
      }
    }
    return null;
  }

  @override
  Future<void> deleteCard(String id) async {
    final cards = await _readAll();
    cards.removeWhere((card) => card.id == id);
    await _writeAll(cards);
  }

  @override
  Future<BusinessCard?> toggleFavorite(String id) async {
    final cards = await _readAll();
    final index = cards.indexWhere((card) => card.id == id);
    if (index < 0) {
      return null;
    }

    final updated = cards[index].copyWith(isFavorite: !cards[index].isFavorite);
    cards[index] = updated;
    await _writeAll(cards);
    return updated;
  }

  @override
  Future<void> clearCards() async {
    await _writeAll(<BusinessCard>[]);
  }

  @override
  Future<List<BusinessCard>> searchCards(String query) async {
    final normalized = query.trim().toLowerCase();
    final cards = await loadCards();

    if (normalized.isEmpty) {
      return cards;
    }

    return cards.where((card) {
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
