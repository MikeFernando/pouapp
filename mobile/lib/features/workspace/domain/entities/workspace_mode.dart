enum WorkspaceMode { rua, gestao }

/// Restores the last mode. Older installs stored `sales` and `stock`.
WorkspaceMode workspaceModeFromStorage(String? value) {
  return switch (value) {
    'gestao' || 'stock' => WorkspaceMode.gestao,
    _ => WorkspaceMode.rua,
  };
}

String workspaceModeStorageValue(WorkspaceMode mode) => mode.name;
