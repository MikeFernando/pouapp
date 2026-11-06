import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/workspace/data/datasources/workspace_local_data_source.dart';
import 'package:pouapp/features/workspace/domain/entities/workspace_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('should restore rua when no mode is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final dataSource = WorkspaceLocalDataSourceImpl(
      sharedPreferences: preferences,
    );

    expect(dataSource.readMode(), WorkspaceMode.rua);
  });

  test(
    'should restore gestão from the current and the previous value',
    () async {
      SharedPreferences.setMockInitialValues({workspaceModeKey: 'gestao'});
      final current = await SharedPreferences.getInstance();
      expect(
        WorkspaceLocalDataSourceImpl(sharedPreferences: current).readMode(),
        WorkspaceMode.gestao,
      );

      SharedPreferences.setMockInitialValues({workspaceModeKey: 'stock'});
      final previous = await SharedPreferences.getInstance();
      expect(
        WorkspaceLocalDataSourceImpl(sharedPreferences: previous).readMode(),
        WorkspaceMode.gestao,
      );
    },
  );

  test('should restore rua when the stored value is unknown', () async {
    SharedPreferences.setMockInitialValues({workspaceModeKey: 'galpao'});
    final preferences = await SharedPreferences.getInstance();
    final dataSource = WorkspaceLocalDataSourceImpl(
      sharedPreferences: preferences,
    );

    expect(dataSource.readMode(), WorkspaceMode.rua);
  });

  test('should persist gestão', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final dataSource = WorkspaceLocalDataSourceImpl(
      sharedPreferences: preferences,
    );

    await dataSource.saveMode(WorkspaceMode.gestao);

    expect(preferences.getString(workspaceModeKey), 'gestao');
    expect(dataSource.readMode(), WorkspaceMode.gestao);
  });
}
