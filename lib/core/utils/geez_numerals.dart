/// Ethiopic (Ge'ez) numerals: 1 → ፩, 10 → ፲, 16 → ፲፮, 100 → ፻, 119 → ፻፲፱,
/// 150 → ፻፶, 176 → ፻፸፮, 1000 → ፲፻, 10000 → ፼.
///
/// Ge'ez has no zero: numbers are written in pairs of digits (tens + ones),
/// joined by ፻ (hundred) and ፼ (ten thousand). A pair that is just "1" in
/// front of ፻ or ፼ is left out (100 is ፻, not ፩፻).
String toGeez(int n) {
  if (n <= 0) return '$n';
  const ones = ['', '፩', '፪', '፫', '፬', '፭', '፮', '፯', '፰', '፱'];
  const tens = ['', '፲', '፳', '፴', '፵', '፶', '፷', '፸', '፹', '፺'];

  // Split into two-digit groups, lowest first.
  final groups = <int>[];
  for (var x = n; x > 0; x ~/= 100) {
    groups.add(x % 100);
  }

  final out = StringBuffer();
  for (var i = groups.length - 1; i >= 0; i--) {
    final g = groups[i];
    // Leading "1" before a ፻/፼ marker is implied, except for the number 1 itself.
    final impliedOne = g == 1 && i > 0 && i == groups.length - 1;
    if (g != 0 && !impliedOne) out.write('${tens[g ~/ 10]}${ones[g % 10]}');
    if (i > 0) {
      // Groups alternate hundred / ten-thousand markers: …፼ ፻ ፼ ፻ (i=1 → ፻, i=2 → ፼).
      final marker = i.isOdd ? '፻' : '፼';
      // Skip a ፻ whose group is empty (e.g. 10000 = ፼, 1000000 = ፻፼).
      if (g != 0 || i.isEven) out.write(marker);
    }
  }
  return out.toString();
}

/// Replaces every run of digits in [text] with Ge'ez numerals:
/// "ዮሐንስ 3:16" → "ዮሐንስ ፫:፲፮", "15–16" → "፲፭–፲፮".
String geezifyDigits(String text) => text.replaceAllMapped(RegExp(r'\d+'), (m) => toGeez(int.parse(m[0]!)));

/// [n] as Ge'ez when [geez] is on, otherwise as ordinary digits.
String formatNumber(int n, {required bool geez}) => geez ? toGeez(n) : '$n';
