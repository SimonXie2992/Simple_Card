import '../models/card_organization.dart';

abstract class CardRepository {
  Future<List<BusinessCard>> loadCards();

  Future<BusinessCard> upsertCard(BusinessCard card);

  Future<BusinessCard?> getCardById(String id);

  Future<void> deleteCard(String id);

  Future<BusinessCard?> toggleFavorite(String id);

  Future<void> clearCards();

  Future<List<BusinessCard>> searchCards(String query);
}
