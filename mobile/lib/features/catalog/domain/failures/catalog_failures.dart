import '../../../../core/error/failures.dart';
import '../entities/catalog.dart';

class CatalogRuleFailure extends Failure {
  const CatalogRuleFailure(this.violation);

  final StockRuleViolation violation;

  @override
  List<Object?> get props => [violation];
}

class ProductNotFoundFailure extends Failure {
  const ProductNotFoundFailure();
}

class StockOperationFailure extends Failure {
  const StockOperationFailure(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
