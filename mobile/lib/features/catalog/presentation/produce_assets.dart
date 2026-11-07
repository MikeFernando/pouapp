String? produceAsset(String name) {
  final text = name.toLowerCase();
  if (text.contains('alho')) return 'assets/produce/alho.jpg';
  if (text.contains('cebola')) return 'assets/produce/cebola.jpg';
  if (text.contains('batata')) return 'assets/produce/batata.jpg';
  if (text.contains('banana')) return 'assets/produce/banana.jpg';
  if (text.contains('tomate')) return 'assets/produce/tomate.jpg';
  if (text.contains('alface')) return 'assets/produce/alface.jpg';
  if (text.contains('laranja')) return 'assets/produce/laranja.jpg';
  if (text.contains('limao') || text.contains('limão')) {
    return 'assets/produce/limao.jpg';
  }
  if (text.contains('mamao') || text.contains('mamão')) {
    return 'assets/produce/mamao.jpg';
  }
  if (text.contains('melancia')) return 'assets/produce/melancia.jpg';
  if (text.contains('ovo')) return 'assets/produce/ovos.jpg';
  return null;
}
