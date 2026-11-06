import 'package:flutter_test/flutter_test.dart';
import 'package:pouapp/features/workspace/domain/entities/workspace_mode.dart';

void main() {
  test('should restore rua by default and gestão from the office values', () {
    expect(workspaceModeFromStorage('gestao'), WorkspaceMode.gestao);
    expect(workspaceModeFromStorage('stock'), WorkspaceMode.gestao);
    expect(workspaceModeFromStorage('rua'), WorkspaceMode.rua);
    expect(workspaceModeFromStorage('sales'), WorkspaceMode.rua);
    expect(workspaceModeFromStorage(null), WorkspaceMode.rua);
    expect(workspaceModeFromStorage('outro'), WorkspaceMode.rua);
  });

  test('should store the current mode name', () {
    expect(workspaceModeStorageValue(WorkspaceMode.rua), 'rua');
    expect(workspaceModeStorageValue(WorkspaceMode.gestao), 'gestao');
  });
}
