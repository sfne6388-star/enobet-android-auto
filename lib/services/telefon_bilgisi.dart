String? aranacakTelefon(String raw) {
  final first = raw
      .trim()
      .replaceFirst(RegExp(r'^tel:', caseSensitive: false), '')
      .split(RegExp(r'[;,/]'))
      .first;
  var number = first.replaceAll(RegExp(r'[^0-9+]'), '');
  if (number.startsWith('0090')) number = '+90${number.substring(4)}';
  if (number.startsWith('+900')) number = '+90${number.substring(4)}';
  if (number.length == 12 && number.startsWith('90')) number = '+$number';
  if (number.length == 10 && !number.startsWith('+')) number = '0$number';
  if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(number)) return null;
  return number;
}

String kayittanTelefon(Map<String, dynamic> tags) {
  for (final key in [
    'phone',
    'contact:phone',
    'telephone',
    'contact:telephone',
    'mobile',
    'contact:mobile',
    'phone:mobile',
    'contact:whatsapp',
    'whatsapp',
    'contact:telephone:mobile',
    'contact:phone:mobile',
  ]) {
    final raw = '${tags[key] ?? ''}'.trim();
    if (aranacakTelefon(raw) != null) return raw;
  }
  return '';
}
