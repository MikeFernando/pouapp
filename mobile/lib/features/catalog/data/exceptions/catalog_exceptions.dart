import '../../domain/entities/catalog.dart';

class ProductNotFoundException implements Exception {}

class CatalogRuleException implements Exception {
  CatalogRuleException(this.violation);

  final StockRuleViolation violation;
}

class StockOperationException implements Exception {
  StockOperationException(this.message);

  final String message;
}
