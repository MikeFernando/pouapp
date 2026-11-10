String? produceAsset(String name) {
  final text = _normalize(name);
  // Longer / more specific keys first so "batata doce" does not hit "batata".
  const photos = <String, String>{
    'batata doce': 'assets/produce/batata_doce.jpg',
    'repolho roxo': 'assets/produce/repolho_roxo.jpg',
    'couve flor': 'assets/produce/couve_flor.jpg',
    'couve-flor': 'assets/produce/couve_flor.jpg',
    'tomate cereja': 'assets/produce/tomate.jpg',
    'alface': 'assets/produce/alface.jpg',
    'cebolinha': 'assets/produce/cebolinha.jpg',
    'cebola': 'assets/produce/cebola.jpg',
    'batata': 'assets/produce/batata.jpg',
    'banana': 'assets/produce/banana.jpg',
    'tomate': 'assets/produce/tomate.jpg',
    'alho': 'assets/produce/alho.jpg',
    'laranja': 'assets/produce/laranja.jpg',
    'tangerina': 'assets/produce/tangerina.jpg',
    'limao': 'assets/produce/limao.jpg',
    'mamao': 'assets/produce/mamao.jpg',
    'melancia': 'assets/produce/melancia.jpg',
    'melao': 'assets/produce/melao.jpg',
    'ovo': 'assets/produce/ovos.jpg',
    'abacate': 'assets/produce/abacate.jpg',
    'abacaxi': 'assets/produce/abacaxi.jpg',
    'acerola': 'assets/produce/acerola.jpg',
    'ameixa': 'assets/produce/ameixa.jpg',
    'amora': 'assets/produce/amora.jpg',
    'caju': 'assets/produce/caju.jpg',
    'caqui': 'assets/produce/caqui.jpg',
    'carambola': 'assets/produce/carambola.jpg',
    'coco': 'assets/produce/coco.jpg',
    'figo': 'assets/produce/figo.jpg',
    'goiaba': 'assets/produce/goiaba.jpg',
    'jabuticaba': 'assets/produce/jabuticaba.jpg',
    'kiwi': 'assets/produce/kiwi.jpg',
    'maca': 'assets/produce/maca.jpg',
    'manga': 'assets/produce/manga.jpg',
    'maracuja': 'assets/produce/maracuja.jpg',
    'morango': 'assets/produce/morango.jpg',
    'pera': 'assets/produce/pera.jpg',
    'pessego': 'assets/produce/pessego.jpg',
    'pitaya': 'assets/produce/pitaya.jpg',
    'uva': 'assets/produce/uva.jpg',
    'agriao': 'assets/produce/agriao.jpg',
    'acelga': 'assets/produce/acelga.jpg',
    'chicoria': 'assets/produce/chicoria.jpg',
    'couve': 'assets/produce/couve.jpg',
    'espinafre': 'assets/produce/espinafre.jpg',
    'rucula': 'assets/produce/rucula.jpg',
    'repolho': 'assets/produce/repolho.jpg',
    'salsa': 'assets/produce/salsa.jpg',
    'coentro': 'assets/produce/coentro.jpg',
    'manjericao': 'assets/produce/manjericao.jpg',
    'hortela': 'assets/produce/hortela.jpg',
    'abobrinha': 'assets/produce/abobrinha.jpg',
    'abobora': 'assets/produce/abobora.jpg',
    'mandioquinha': 'assets/produce/mandioquinha.jpg',
    'berinjela': 'assets/produce/berinjela.jpg',
    'beterraba': 'assets/produce/beterraba.jpg',
    'brocolis': 'assets/produce/brocolis.jpg',
    'cenoura': 'assets/produce/cenoura.jpg',
    'chuchu': 'assets/produce/chuchu.jpg',
    'inhame': 'assets/produce/inhame.jpg',
    'jilo': 'assets/produce/jilo.jpg',
    'mandioca': 'assets/produce/mandioca.jpg',
    'milho': 'assets/produce/milho.jpg',
    'pepino': 'assets/produce/pepino.jpg',
    'pimentao': 'assets/produce/pimentao.jpg',
    'quiabo': 'assets/produce/quiabo.jpg',
    'rabanete': 'assets/produce/rabanete.jpg',
    'vagem': 'assets/produce/vagem.jpg',
    'maxixe': 'assets/produce/maxixe.jpg',
    'nabo': 'assets/produce/nabo.jpg',
  };
  for (final entry in photos.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  return null;
}

String _normalize(String name) {
  final lower = name.toLowerCase();
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final buffer = StringBuffer();
  for (final code in lower.runes) {
    final char = String.fromCharCode(code);
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer.toString();
}
