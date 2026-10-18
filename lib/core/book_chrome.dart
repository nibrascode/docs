/// Page number and footnote helpers shared by the editor and PDF.
String easternDigits(String n) {
  const map = {
    '0': '٠',
    '1': '١',
    '2': '٢',
    '3': '٣',
    '4': '٤',
    '5': '٥',
    '6': '٦',
    '7': '٧',
    '8': '٨',
    '9': '٩',
  };
  return n.split('').map((c) => map[c] ?? c).join();
}

String formatPageNumber(int n, String style) {
  final eastern = style == 'eastern' || style == 'easternDash';
  final digits = eastern ? easternDigits('$n') : '$n';
  if (style == 'dashed' || style == 'easternDash') return '- $digits -';
  return digits;
}

bool pageNumberInOval(String style) => style == 'oval';
