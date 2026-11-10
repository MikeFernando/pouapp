import '../../../../core/config/api_config.dart';
import '../../../../injection_container.dart';
import 'bloc/company_operation_bloc.dart';
import 'bloc/home_board_bloc.dart';

/// One company record shared by Entregas and the customer account.
CompanyOperationBloc loadedCompanyOperation() {
  final bloc = sl<CompanyOperationBloc>();
  if (bloc.state.status == BoardStatus.initial) {
    bloc.add(const CompanyOperationRequested());
  }
  return bloc;
}

HomeBoardBloc? loadedHomeBoard() {
  if (!ApiConfig.useRemoteApi) return null;
  final bloc = sl<HomeBoardBloc>();
  if (bloc.state.status == HomeBoardStatus.initial) {
    bloc.add(const HomeBoardRequested());
  }
  return bloc;
}
