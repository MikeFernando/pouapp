import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../injection_container.dart';
import '../domain/entities/street_ledger.dart';
import 'bloc/company_operation_bloc.dart';
import 'operation_labels.dart';
import '../domain/usecases/workspace_use_cases.dart';

Future<bool> applyStreetChange(
  BuildContext context,
  StreetChange change,
) async {
  final result = await sl<ApplyStreetChange>()(change);
  if (!context.mounted) return false;
  return result.fold(
    (failure) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(operationFailureMessage(failure))));
      return false;
    },
    (operation) {
      context.read<CompanyOperationBloc>().add(
        CompanyOperationUpdated(operation),
      );
      return true;
    },
  );
}
