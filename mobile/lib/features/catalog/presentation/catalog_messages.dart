import '../../../../core/error/failures.dart';
import '../domain/entities/catalog.dart';
import '../domain/failures/catalog_failures.dart';

String catalogFailureMessage(Failure failure) {
  return switch (failure) {
    CatalogRuleFailure(:final violation) => switch (violation) {
      StockRuleViolation.nameRequired => 'Informe o nome do produto.',
      StockRuleViolation.negativeQuantity =>
        'A quantidade não pode ser negativa.',
      StockRuleViolation.fractionalCount =>
        'Unidade, maço e caixa usam quantidade inteira.',
      StockRuleViolation.incompatibleUnit =>
        'Não é possível converter unidades diferentes.',
      StockRuleViolation.duplicateOpening => 'Este local já tem saldo inicial.',
      StockRuleViolation.productInactive =>
        'Produto inativo não recebe movimentação.',
      StockRuleViolation.deleteWithHistory =>
        'Produto com histórico não pode ser excluído. Inative o cadastro.',
    },
    ProductNotFoundFailure() => 'Produto não encontrado.',
    StockOperationFailure(:final message) => message,
    CacheFailure() => 'Não foi possível ler o estoque neste aparelho.',
    _ => 'Não foi possível concluir. Tente novamente.',
  };
}
