import '../../../../injection_container.dart';
import 'bloc/company_operation_bloc.dart';

/// One company record shared by Gestão, Entregas and the customer account.
CompanyOperationBloc loadedCompanyOperation() {
  final bloc = sl<CompanyOperationBloc>();
  if (bloc.state.status == BoardStatus.initial) {
    bloc.add(const CompanyOperationRequested());
  }
  return bloc;
}
