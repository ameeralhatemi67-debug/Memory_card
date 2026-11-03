/// The arithmetic of Make 24 (tools/make24.py, the same rules): exact fractions, expressions, and the one
/// written form every way has, so a way built on the card can be told apart from the others.
///
/// Two ways are the same when they differ only in order or grouping: sums and products are flattened and
/// their parts sorted, and what changes nothing (× a 1, + a 0, + x − x, × x ÷ x) is taken out wherever it
/// sits and put back at the top. The written form puts bracketed parts first, then bigger numbers, and
/// what is taken away or divided last: "(8 − 6) × 4 × 3".
class Frac implements Comparable<Frac> {
  factory Frac(int n, [int d = 1]) {
    if (d < 0) {
      n = -n;
      d = -d;
    }
    final g = _gcd(n.abs(), d);
    return Frac._(n ~/ g, d ~/ g);
  }
  const Frac._(this.n, this.d);
  final int n, d;

  static int _gcd(int a, int b) {
    while (b != 0) {
      final t = a % b;
      a = b;
      b = t;
    }
    return a == 0 ? 1 : a;
  }

  static const zero = Frac._(0, 1), one = Frac._(1, 1), target = Frac._(24, 1);

  Frac operator +(Frac o) => Frac(n * o.d + o.n * d, d * o.d);
  Frac operator -(Frac o) => Frac(n * o.d - o.n * d, d * o.d);
  Frac operator *(Frac o) => Frac(n * o.n, d * o.d);

  /// null when dividing by 0.
  Frac? div(Frac o) => o.n == 0 ? null : Frac(n * o.d, d * o.n);

  bool get whole => d == 1;
  bool get negative => n < 0;

  @override
  int compareTo(Frac o) => (n * o.d - o.n * d).sign;
  @override
  bool operator ==(Object other) => other is Frac && other.n == n && other.d == d;
  @override
  int get hashCode => Object.hash(n, d);
  @override
  String toString() => d == 1 ? '$n' : '$n/$d';
}

const minusSign = '−', timesSign = '×', overSign = '÷';

/// How each operator is written: + − × ÷.
String opSign(String op) => switch (op) { '-' => minusSign, '*' => timesSign, '/' => overSign, _ => '+' };

/// An expression: a number, or two expressions joined by + - * /.
class Expr {
  const Expr.num(this.v)
      : op = null,
        l = null,
        r = null;
  const Expr.join(String this.op, Expr this.l, Expr this.r) : v = 0;

  final String? op;
  final int v;
  final Expr? l, r;

  bool get isNum => op == null;

  Frac? get value {
    if (isNum) return Frac(v);
    final a = l!.value, b = r!.value;
    if (a == null || b == null) return null;
    return switch (op) { '+' => a + b, '-' => a - b, '*' => a * b, _ => a.div(b) };
  }

  /// The numbers it uses, in order.
  List<int> get numbers => isNum ? [v] : [...l!.numbers, ...r!.numbers];

  /// Reads a written way: numbers, + − × ÷ (or + - * /) and brackets, × ÷ before + −.
  static Expr parse(String text) {
    final tokens = RegExp(r'\d+|[()+\-*/−×÷]').allMatches(text).map((m) => m[0]!).toList();
    var i = 0;
    String norm(String t) => switch (t) { minusSign => '-', timesSign => '*', overSign => '/', _ => t };
    late Expr Function() sum;
    Expr atom() {
      if (i >= tokens.length) throw const FormatException('unfinished');
      final t = tokens[i++];
      if (t == '(') {
        final e = sum();
        if (i >= tokens.length || tokens[i] != ')') throw const FormatException('bracket');
        i++;
        return e;
      }
      final n = int.tryParse(t);
      if (n == null) throw FormatException('unexpected $t');
      return Expr.num(n);
    }

    Expr product() {
      var e = atom();
      while (i < tokens.length && (norm(tokens[i]) == '*' || norm(tokens[i]) == '/')) {
        final op = norm(tokens[i++]);
        e = Expr.join(op, e, atom());
      }
      return e;
    }

    sum = () {
      var e = product();
      while (i < tokens.length && (norm(tokens[i]) == '+' || norm(tokens[i]) == '-')) {
        final op = norm(tokens[i++]);
        e = Expr.join(op, e, product());
      }
      return e;
    };
    final e = sum();
    if (i != tokens.length) throw const FormatException('extra');
    return e;
  }

  /// The steps of working it out, innermost first: "8 − 6 = 2", "2 × 4 = 8", "8 × 3 = 24".
  List<String> get steps {
    if (isNum) return const [];
    final a = l!.value!, b = r!.value!;
    return [...l!.steps, ...r!.steps, '$a ${opSign(op!)} $b = $value'];
  }
}

/// The written form of the way [e] is, the same for every way that differs only in order or grouping.
String wayOf(Expr e) {
  final pulled = <String, List<_Part>>{'S': [], 'P': []};
  var r = _simplify(_norm(e), pulled);
  if (pulled['S']!.isNotEmpty) r = _make('S', [_Part(r, 1), ...pulled['S']!]);
  if (pulled['P']!.isNotEmpty) r = _make('P', [_Part(r, 1), ...pulled['P']!]);
  return _show(r);
}

// ---------------------------------------------------------------- the canonical form

/// A number (k 'N'), a flat sum (k 'S', parts with signs) or a flat product (k 'P', parts with ±1 powers).
class _Node {
  _Node.num(this.v)
      : k = 'N',
        parts = const [];
  _Node(this.k, this.parts) : v = 0;
  final String k;
  final int v;
  final List<_Part> parts;

  late final String key = k == 'N' ? 'N$v' : '$k[${parts.map((p) => '${p.n.key}${p.s > 0 ? '+' : '-'}').join(',')}]';

  late final Frac value = switch (k) {
    'N' => Frac(v),
    'S' => parts.fold(Frac.zero, (a, p) => p.s > 0 ? a + p.n.value : a - p.n.value),
    _ => parts.fold(Frac.one, (a, p) => p.s > 0 ? a * p.n.value : a.div(p.n.value)!),
  };
}

class _Part {
  const _Part(this.n, this.s);
  final _Node n;
  final int s;
}

List<_Part> _sorted(List<_Part> parts) => [...parts]..sort((x, y) => '${x.n.key}${x.s}'.compareTo('${y.n.key}${y.s}'));

_Node _norm(Expr t) {
  if (t.isNum) return _Node.num(t.v);
  final sum = t.op == '+' || t.op == '-';
  final parts = <_Part>[];
  void flat(Expr x, int s) {
    if (sum && (x.op == '+' || x.op == '-')) {
      flat(x.l!, s);
      flat(x.r!, x.op == '+' ? s : -s);
    } else if (!sum && (x.op == '*' || x.op == '/')) {
      flat(x.l!, s);
      flat(x.r!, x.op == '*' ? s : -s);
    } else {
      final v = x.value!;
      parts.add(_Part(_norm(x), sum ? (v == Frac.zero ? 1 : s) : (v == Frac.one ? 1 : s)));
    }
  }

  flat(t, 1);
  return _Node(sum ? 'S' : 'P', _sorted(parts));
}

_Node _make(String k, List<_Part> parts) {
  final flat = <_Part>[];
  for (final p in parts) {
    if (p.n.k == k) {
      flat.addAll(p.n.parts.map((q) => _Part(q.n, q.s * p.s)));
    } else {
      flat.add(p);
    }
  }
  if (flat.length == 1 && flat.first.s == 1) return flat.first.n;
  return _Node(k, _sorted(flat));
}

_Node _simplify(_Node n, Map<String, List<_Part>> pulled) {
  if (n.k == 'N') return n;
  final parts = [for (final p in n.parts) _Part(_simplify(p.n, pulled), p.s)];
  final neutral = n.k == 'P' ? Frac.one : Frac.zero;
  final keep = <_Part>[], out = <_Part>[];
  for (final p in parts) {
    p.n.value == neutral ? out.add(_Part(p.n, 1)) : keep.add(p);
  }
  final rest = <_Part>[];
  for (final p in keep) {
    final twin = rest.indexWhere((q) => q.s == -p.s && q.n.key == p.n.key);
    if (twin < 0) {
      rest.add(p);
    } else {
      out.addAll([rest.removeAt(twin), p]);
    }
  }
  if (rest.isEmpty || rest.every((p) => p.s < 0)) return _make(n.k, parts);
  pulled[n.k]!.addAll(out);
  return _make(n.k, rest);
}

List<_Part> _ordered(_Node n) => [...n.parts]..sort((x, y) {
    if ((x.s < 0) != (y.s < 0)) return x.s < 0 ? 1 : -1;
    final cx = x.n.k != 'N', cy = y.n.k != 'N';
    if (cx != cy) return cx ? -1 : 1;
    final c = y.n.value.compareTo(x.n.value);
    if (c != 0) return c;
    return x.n.key.compareTo(y.n.key);
  });

String _show(_Node n) {
  if (n.k == 'N') return '${n.v}';
  final out = StringBuffer();
  final parts = _ordered(n);
  for (var i = 0; i < parts.length; i++) {
    final p = parts[i];
    if (n.k == 'S') {
      final t = _show(p.n);
      out.write(p.s > 0 ? (i == 0 ? t : ' + $t') : (i == 0 ? '$minusSign $t' : ' $minusSign $t'));
    } else {
      final t = p.n.k == 'S' ? '(${_show(p.n)})' : _show(p.n);
      out.write(i == 0 ? t : ' ${p.s > 0 ? timesSign : overSign} $t');
    }
  }
  return out.toString();
}
