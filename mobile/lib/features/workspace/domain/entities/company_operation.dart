import 'package:equatable/equatable.dart';

import 'posted_sale.dart';
import 'sales_board.dart';
import 'stock_board.dart';
import 'street_ledger.dart';

/// One company snapshot shared by Entregas and the customer account.
class CompanyOperation extends Equatable {
  const CompanyOperation({
    required this.summary,
    required this.deliveries,
    required this.sales,
    required this.team,
    required this.stock,
    required this.receipts,
    required this.products,
    this.street = const StreetLedger(),
    this.accountPayments = const [],
    this.postedSales = const [],
  });

  final SalesSummary summary;
  final List<DeliveryStop> deliveries;
  final List<RecentSale> sales;
  final List<TeamPending> team;
  final StockSummary stock;
  final List<StockReceipt> receipts;
  final List<StockProduct> products;
  final StreetLedger street;

  /// Confirmed account receipts. A prepared charge is not a payment.
  final List<CustomerPayment> accountPayments;

  /// Confirmed sales and opening balances used by the month dashboard.
  final List<PostedSale> postedSales;

  CompanyOperation copyWith({
    SalesSummary? summary,
    List<DeliveryStop>? deliveries,
    List<RecentSale>? sales,
    List<TeamPending>? team,
    StockSummary? stock,
    List<StockReceipt>? receipts,
    List<StockProduct>? products,
    StreetLedger? street,
    List<CustomerPayment>? accountPayments,
    List<PostedSale>? postedSales,
  }) {
    return CompanyOperation(
      summary: summary ?? this.summary,
      deliveries: deliveries ?? this.deliveries,
      sales: sales ?? this.sales,
      team: team ?? this.team,
      stock: stock ?? this.stock,
      receipts: receipts ?? this.receipts,
      products: products ?? this.products,
      street: street ?? this.street,
      accountPayments: accountPayments ?? this.accountPayments,
      postedSales: postedSales ?? this.postedSales,
    );
  }

  @override
  List<Object?> get props => [
    summary,
    deliveries,
    sales,
    team,
    stock,
    receipts,
    products,
    street,
    accountPayments,
    postedSales,
  ];
}
