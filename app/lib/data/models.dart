// Plain data classes for everything Memory Card stores. No Flutter imports, so the engine and its tests
// run anywhere. Every class round-trips through JSON-compatible maps (Hive stores them as-is).

import '../engine/assessor.dart';
import '../engine/baselines.dart';
import '../engine/calibration.dart';
import 'card_layout.dart';

int _i(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;
double? _dn(Object? v) => (v as num?)?.toDouble();
double _d(Object? v, [double d = 0]) => (v as num?)?.toDouble() ?? d;
String _s(Object? v, [String d = '']) => (v as String?) ?? d;
bool _b(Object? v, [bool d = false]) => (v as bool?) ?? d;
List<String> _ls(Object? v) => ((v as List?) ?? const []).map((e) => e as String).toList();

class Folder {
  Folder({required this.id, required this.name, List<String>? deckIds, required this.created})
      : deckIds = deckIds ?? <String>[];

  final String id;
  String name;
  final List<String> deckIds;
  final int created;

  bool get isArchive => id == archiveId;
  static const archiveId = 'f-archive';

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'decks': deckIds, 'created': created};

  factory Folder.fromJson(Map j) =>
      Folder(id: j['id'] as String, name: _s(j['name']), deckIds: _ls(j['decks']), created: _i(j['created']));
}

class Deck {
  Deck({
    required this.id,
    required this.name,
    this.mono = '',
    this.category = 'custom',
    this.kind = 'text',
    this.level = '',
    this.description = '',
    this.lang,
    this.catalogId,
    this.pinned = false,
    List<String>? cardIds,
    List<String>? stack,
    List<String>? reservoir,
    this.ema = 0.75,
    this.lastStudied = 0,
    required this.created,
    this.prevFolderId,
    this.pace,
    this.typing = false,
    this.reviews = 0,
    this.masteredAt,
  })  : cardIds = cardIds ?? <String>[],
        stack = stack ?? <String>[],
        reservoir = reservoir ?? <String>[];

  final String id;
  String name;
  String mono;

  /// lang · code · med · science · knowledge · custom
  String category;

  /// text · code (code fronts use a monospace face)
  String kind;
  String level;
  String description;

  /// BCP-47 tag of the front side, for "Hear it".
  String? lang;
  String? catalogId;
  bool pinned;

  /// Every card of the deck.
  final List<String> cardIds;

  /// The endless stack: active cards in study order. Index 0 is on top.
  List<String> stack;

  /// Cards not introduced yet (pacing, RES-47 §5.2).
  List<String> reservoir;

  /// Rolling felt success (EMA, α = 0.05).
  double ema;
  int lastStudied;
  final int created;
  String? prevFolderId;

  /// Per-deck pace override; null follows the setting.
  String? pace;

  /// Type the answer before checking.
  bool typing;
  int reviews;

  /// When every card first stood above 90 % recall (the "mastered" seal), once per deck.
  int? masteredAt;

  String get monogram => mono.isNotEmpty ? mono : _monoFrom(name);

  static String _monoFrom(String name) {
    final words = name.replaceAll('·', ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    final w = words.first;
    return w.length >= 2 ? '${w[0].toUpperCase()}${w[1].toLowerCase()}' : w.toUpperCase();
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'mono': mono,
        'cat': category,
        'kind': kind,
        'level': level,
        'desc': description,
        'lang': lang,
        'catalog': catalogId,
        'pinned': pinned,
        'cards': cardIds,
        'stack': stack,
        'res': reservoir,
        'ema': ema,
        'last': lastStudied,
        'created': created,
        'prev': prevFolderId,
        'pace': pace,
        'typing': typing,
        'reviews': reviews,
        if (masteredAt != null) 'mastered': masteredAt,
      };

  factory Deck.fromJson(Map j) => Deck(
        id: j['id'] as String,
        name: _s(j['name']),
        mono: _s(j['mono']),
        category: _s(j['cat'], 'custom'),
        kind: _s(j['kind'], 'text'),
        level: _s(j['level']),
        description: _s(j['desc']),
        lang: j['lang'] as String?,
        catalogId: j['catalog'] as String?,
        pinned: _b(j['pinned']),
        cardIds: _ls(j['cards']),
        stack: _ls(j['stack']),
        reservoir: _ls(j['res']),
        ema: _d(j['ema'], 0.75),
        lastStudied: _i(j['last']),
        created: _i(j['created']),
        prevFolderId: j['prev'] as String?,
        pace: j['pace'] as String?,
        typing: _b(j['typing']),
        reviews: _i(j['reviews']),
        masteredAt: (j['mastered'] as num?)?.toInt(),
      );
}

/// One past review kept on the card itself, for its history strip.
class CardEvent {
  const CardEvent(this.ts, this.grade, this.thinkMs);
  final int ts;
  final int grade;
  final int thinkMs;
}

class CardItem {
  CardItem({
    required this.id,
    required this.deckId,
    required this.front,
    required this.back,
    this.label = '',
    this.example = '',
    this.hook = '',
    this.image,
    this.frontLayout,
    this.backLayout,
    this.isReverse = false,
    this.siblingId,
    this.suspended = false,
    required this.created,
    this.s,
    this.d,
    this.last,
    this.reps = 0,
    this.lapses = 0,
    this.succ = 0,
    this.leech = false,
    this.lastGrade,
    this.lastConfidence,
    this.firstSeen,
    List<int>? hist,
  }) : hist = hist ?? <int>[];

  final String id;
  String deckId;
  String front;
  String back;
  String label;

  /// Context shown before the answer (never the answer itself).
  String example;

  /// Memory hook shown with the answer.
  String hook;

  /// Image path (mobile) or data URI (web). Cards made before layouts: shown under the prompt.
  String? image;

  /// How each side is laid out (pictures, text placement). null = the classic text card.
  SideLayout? frontLayout;
  SideLayout? backLayout;
  bool isReverse;
  String? siblingId;
  bool suspended;
  final int created;

  // ---- memory (FSRS-6 shadow model + engine bookkeeping) ----
  double? s;
  double? d;

  /// Time of the last review, ms since epoch.
  int? last;
  int reps;
  int lapses;
  int succ;
  bool leech;
  int? lastGrade;
  double? lastConfidence;
  int? firstSeen;

  /// Recent reviews, flattened as [tsSeconds, grade, thinkMs ÷ 10] triples, newest last.
  final List<int> hist;
  static const histMax = 24;

  bool get isNew => s == null;
  double get successRate => reps == 0 ? 0 : succ / reps;

  /// A picture on the front, from a layout or the older single image.
  bool get hasFrontPicture => frontLayout?.hasImage ?? (image != null && image!.isNotEmpty);
  bool get hasBackPicture => backLayout?.hasImage ?? false;

  /// The answer needs its own face (pictures or a free canvas) instead of the text pill under the prompt.
  bool get hasRichBack => backLayout != null && (backLayout!.hasImage || backLayout!.mode == LayoutMode.canvas);

  /// What lists and search show for a side that is only a picture.
  String get frontText => front.isNotEmpty ? front : (hasFrontPicture ? 'Picture' : '');
  String get backText => back.isNotEmpty ? back : (hasBackPicture ? 'Picture' : '');

  /// The first picture to use as a thumbnail (front first).
  String? get thumbSrc => frontLayout?.firstImage?.src ?? ((image != null && image!.isNotEmpty) ? image : backLayout?.firstImage?.src);

  /// The side that is read out for the deck's language.
  String get spokenSide => isReverse ? back : front;

  List<CardEvent> get events => [
        for (var i = 0; i + 2 < hist.length; i += 3) CardEvent(hist[i] * 1000, hist[i + 1], hist[i + 2] * 10),
      ];

  void pushEvent(int tsMs, int grade, int thinkMs) {
    hist.addAll([tsMs ~/ 1000, grade, (thinkMs ~/ 10).clamp(0, 1 << 30)]);
    while (hist.length > histMax * 3) {
      hist.removeRange(0, 3);
    }
  }

  void resetMemory() {
    s = null;
    d = null;
    last = null;
    reps = 0;
    lapses = 0;
    succ = 0;
    leech = false;
    lastGrade = null;
    lastConfidence = null;
    firstSeen = null;
    hist.clear();
  }

  CardItem copy() => CardItem.fromJson(toJson());

  Map<String, Object?> toJson() => {
        'id': id,
        'deck': deckId,
        'f': front,
        'b': back,
        'l': label,
        'e': example,
        'h': hook,
        'img': image,
        if (frontLayout != null) 'fl': frontLayout!.toJson(),
        if (backLayout != null) 'bl': backLayout!.toJson(),
        'rev': isReverse,
        'sib': siblingId,
        'sus': suspended,
        'created': created,
        's': s,
        'd': d,
        'last': last,
        'reps': reps,
        'lapses': lapses,
        'succ': succ,
        'leech': leech,
        'lg': lastGrade,
        'lc': lastConfidence,
        'first': firstSeen,
        'hist': hist,
      };

  factory CardItem.fromJson(Map j) => CardItem(
        id: j['id'] as String,
        deckId: _s(j['deck']),
        front: _s(j['f']),
        back: _s(j['b']),
        label: _s(j['l']),
        example: _s(j['e']),
        hook: _s(j['h']),
        image: j['img'] as String?,
        frontLayout: SideLayout.fromJson(j['fl']),
        backLayout: SideLayout.fromJson(j['bl']),
        isReverse: _b(j['rev']),
        siblingId: j['sib'] as String?,
        suspended: _b(j['sus']),
        created: _i(j['created']),
        s: _dn(j['s']),
        d: _dn(j['d']),
        last: (j['last'] as num?)?.toInt(),
        reps: _i(j['reps']),
        lapses: _i(j['lapses']),
        succ: _i(j['succ']),
        leech: _b(j['leech']),
        lastGrade: (j['lg'] as num?)?.toInt(),
        lastConfidence: _dn(j['lc']),
        firstSeen: (j['first'] as num?)?.toInt(),
        hist: ((j['hist'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
      );
}

enum RevealMode { tap, icon, flip, front }

enum Pace { relaxed, balanced, intense }

/// One textured element: which texture ("none" for plain) and how strong (0…1).
class TextureLayer {
  TextureLayer(this.style, this.strength);
  String style;
  double strength;

  bool get on => style != 'none' && strength > 0;

  List<Object> toJson() => [style, double.parse(strength.toStringAsFixed(3))];
  static TextureLayer fromJson(Object? j, TextureLayer fallback) {
    if (j is! List || j.length < 2) return TextureLayer(fallback.style, fallback.strength);
    return TextureLayer('${j[0]}', ((j[1] as num?)?.toDouble() ?? fallback.strength).clamp(0.0, 1.0));
  }
}

/// Every texture in the app, per element. Defaults: a faint felt wall in light mode, faint concrete in dark
/// mode, plain cards and tiles, card-stock buttons, kraft folders, wax seals; grain and vignette off.
class TextureSettings {
  TextureSettings();

  bool enabled = true;
  final Map<String, TextureLayer> layers = {for (final e in defaults.entries) e.key: TextureLayer(e.value.style, e.value.strength)};

  /// Soft daylight falling across the wall from the top left.
  bool windowLight = true;
  double windowStrength = 0.5;

  /// Corners darken a little, like a lit room.
  bool vignette = false;
  double vignetteStrength = 0.4;

  static final defaults = <String, TextureLayer>{
    'wallLight': TextureLayer('felt', 0.10),
    'wallDark': TextureLayer('concrete', 0.05),
    'cards': TextureLayer('none', 0.5),
    'tiles': TextureLayer('none', 0.4),
    'buttons': TextureLayer('cardstock', 0.20),
    'sheets': TextureLayer('wall', 0.15),
    'folders': TextureLayer('kraft', 0.15),
    'seals': TextureLayer('wax', 0.55),
    'grain': TextureLayer('none', 0.4),
  };

  TextureLayer layer(String id) => layers[id] ?? defaults[id]!;

  Map<String, Object?> toJson() => {
        'on': enabled,
        'layers': {for (final e in layers.entries) e.key: e.value.toJson()},
        'window': windowLight,
        'windowS': windowStrength,
        'vig': vignette,
        'vigS': vignetteStrength,
      };

  factory TextureSettings.fromJson(Map? j) {
    final t = TextureSettings();
    if (j == null) return t;
    t.enabled = _b(j['on'], true);
    final raw = (j['layers'] as Map?) ?? const {};
    for (final id in defaults.keys) {
      t.layers[id] = TextureLayer.fromJson(raw[id], defaults[id]!);
    }
    t.windowLight = _b(j['window'], true);
    t.windowStrength = _d(j['windowS'], 0.5);
    t.vignette = _b(j['vig']);
    t.vignetteStrength = _d(j['vigS'], 0.4);
    return t;
  }
}

class Settings {
  Settings();

  RevealMode reveal = RevealMode.tap;
  Pace pace = Pace.balanced;
  int goal = 20;

  /// light · dark · system
  String theme = 'system';
  bool sounds = true;
  bool haptics = true;
  bool reducedMotion = false;
  bool remind = false;
  int remindMinutes = 19 * 60;

  /// Read hesitation and confidence to choose Hard / Good / Easy.
  bool smartGrading = true;

  /// Mastered cards (recall ≥ 97 %, stability ≥ 30 days) skip their turn.
  bool restMastered = true;
  bool autoSpeak = false;
  bool ignoreAccents = true;
  String name = '';

  /// Show the grade chip after each swipe.
  bool showGrade = true;

  /// Pictures that wait for the reveal: blur · hide · show.
  String imageReveal = 'blur';

  /// How strongly they blur, 0…1 (Settings › Study).
  double blurAmount = 0.45;

  /// Surface textures (Settings › Texture).
  TextureSettings texture = TextureSettings();

  // ---- Home screen widgets (Settings › Home screen widgets)

  /// auto follows the phone · light · dark
  String widgetTheme = 'auto';

  /// red · orange · green · blue · violet (the colour of the seal, flame and rings)
  String widgetAccent = 'red';

  /// round · soft · square
  String widgetCorners = 'round';

  /// How solid a widget's face is, 30–100 %.
  int widgetOpacity = 100;

  /// Widgets move: a turning seal, a flickering flame, cards that turn over.
  bool widgetMotion = true;

  /// Quick card: stacked · side (the prompt and the buttons side by side).
  String widgetQuick = 'stacked';

  /// A widget's face when it is not the one it was designed with: kind → paper · ink.
  Map<String, String> widgetSurfaces = {};

  /// Gaussian sigma for the blur at [blurAmount]; 0 when pictures are not blurred.
  double get blurSigma => imageReveal == 'blur' ? 6 + 34 * blurAmount : 0;

  double get paceTarget => switch (pace) { Pace.relaxed => 0.80, Pace.balanced => 0.75, Pace.intense => 0.0 };

  Map<String, Object?> toJson() => {
        'reveal': reveal.name,
        'pace': pace.name,
        'goal': goal,
        'theme': theme,
        'sounds': sounds,
        'haptics': haptics,
        'reduced': reducedMotion,
        'remind': remind,
        'remindAt': remindMinutes,
        'smart': smartGrading,
        'rest': restMastered,
        'autoSpeak': autoSpeak,
        'accents': ignoreAccents,
        'name': name,
        'showGrade': showGrade,
        'imgReveal': imageReveal,
        'blurAmt': double.parse(blurAmount.toStringAsFixed(3)),
        'texture': texture.toJson(),
        'wTheme': widgetTheme,
        'wAccent': widgetAccent,
        'wCorners': widgetCorners,
        'wOpacity': widgetOpacity,
        'wMotion': widgetMotion,
        'wQuick': widgetQuick,
        'wSurf': widgetSurfaces,
      };

  factory Settings.fromJson(Map? j) {
    final s = Settings();
    if (j == null) return s;
    s.reveal = RevealMode.values.firstWhere((e) => e.name == j['reveal'], orElse: () => RevealMode.tap);
    s.pace = Pace.values.firstWhere((e) => e.name == j['pace'], orElse: () => Pace.balanced);
    s.goal = _i(j['goal'], 20);
    s.theme = _s(j['theme'], 'system');
    s.sounds = _b(j['sounds'], true);
    s.haptics = _b(j['haptics'], true);
    s.reducedMotion = _b(j['reduced']);
    s.remind = _b(j['remind']);
    s.remindMinutes = _i(j['remindAt'], 19 * 60);
    s.smartGrading = _b(j['smart'], true);
    s.restMastered = _b(j['rest'], true);
    s.autoSpeak = _b(j['autoSpeak']);
    s.ignoreAccents = _b(j['accents'], true);
    s.name = _s(j['name']);
    s.showGrade = _b(j['showGrade'], true);
    final reveal = _s(j['imgReveal'], 'blur');
    s.imageReveal = const ['blur', 'hide', 'show'].contains(reveal) ? reveal : 'blur';
    s.blurAmount = _d(j['blurAmt'], 0.45).clamp(0.0, 1.0);
    s.texture = TextureSettings.fromJson(j['texture'] as Map?);
    String pick(Object? v, List<String> allowed) => allowed.contains(v) ? v as String : allowed.first;
    s.widgetTheme = pick(j['wTheme'], const ['auto', 'light', 'dark']);
    s.widgetAccent = pick(j['wAccent'], const ['red', 'orange', 'green', 'blue', 'violet']);
    s.widgetCorners = pick(j['wCorners'], const ['round', 'soft', 'square']);
    s.widgetOpacity = _i(j['wOpacity'], 100).clamp(30, 100);
    s.widgetMotion = _b(j['wMotion'], true);
    s.widgetQuick = pick(j['wQuick'], const ['stacked', 'side']);
    ((j['wSurf'] as Map?) ?? const {}).forEach((k, v) {
      if (v == 'paper' || v == 'ink') s.widgetSurfaces['$k'] = v as String;
    });
    return s;
  }
}

/// One study day in the history (heatmap, Memory Lab).
class DayRecord {
  DayRecord({this.swipes = 0, this.ok = 0, this.ms = 0, this.goal = false});
  int swipes;
  int ok;
  int ms;
  bool goal;

  List<int> toJson() => [swipes, ok, ms, goal ? 1 : 0];
  factory DayRecord.fromJson(Object? j) {
    if (j is List) return DayRecord(swipes: _i(j[0]), ok: _i(j[1]), ms: _i(j[2]), goal: j.length > 3 && j[3] == 1);
    if (j is num) return DayRecord(swipes: j.toInt());
    return DayRecord();
  }
}

class Profile {
  Profile({required this.since});

  int streak = 0;
  int bestStreak = 0;
  int shields = 2;
  String shieldMonth = '';

  /// Study day number of the last day the goal was met.
  int lastGoalDay = -100000;
  final int since;

  /// Study day number → record.
  final Map<int, DayRecord> history = {};

  /// Seal id → study day earned.
  final Map<String, int> seals = {};
  int totalReviews = 0;
  int totalMs = 0;

  /// What happened at the last day change ("shield" / "broken").
  List<String> lastEvents = [];

  Map<String, Object?> toJson() => {
        'streak': streak,
        'best': bestStreak,
        'shields': shields,
        'shieldMonth': shieldMonth,
        'lastGoal': lastGoalDay,
        'since': since,
        'hist': history.map((k, v) => MapEntry('$k', v.toJson())),
        'seals': seals,
        'total': totalReviews,
        'totalMs': totalMs,
        'events': lastEvents,
      };

  factory Profile.fromJson(Map j) {
    final p = Profile(since: _i(j['since']));
    p.streak = _i(j['streak']);
    p.bestStreak = _i(j['best']);
    p.shields = _i(j['shields'], 2);
    p.shieldMonth = _s(j['shieldMonth']);
    p.lastGoalDay = _i(j['lastGoal'], -100000);
    ((j['hist'] as Map?) ?? const {}).forEach((k, v) => p.history[int.parse('$k')] = DayRecord.fromJson(v));
    ((j['seals'] as Map?) ?? const {}).forEach((k, v) => p.seals['$k'] = _i(v));
    p.totalReviews = _i(j['total']);
    p.totalMs = _i(j['totalMs']);
    p.lastEvents = _ls(j['events']);
    return p;
  }
}

class Today {
  Today({required this.day, required this.startedAt, List<String>? slipStart})
      : slipStart = slipStart ?? <String>[];

  final int day;
  final int startedAt;
  int done = 0;
  int ok = 0;
  int fail = 0;
  int ms = 0;
  int newSeen = 0;
  final Set<String> seen = {};

  /// Cards that were slipping when the day began (the goal can be met by seeing each once).
  final List<String> slipStart;
  bool goalHit = false;
  final Map<String, int> decks = {};
  String? lastDeck;
  int run = 0;
  int bestRun = 0;
  int easy = 0;
  int hard = 0;

  Map<String, Object?> toJson() => {
        'day': day,
        'started': startedAt,
        'done': done,
        'ok': ok,
        'fail': fail,
        'ms': ms,
        'new': newSeen,
        'seen': seen.toList(),
        'slip': slipStart,
        'goal': goalHit,
        'decks': decks,
        'lastDeck': lastDeck,
        'run': run,
        'bestRun': bestRun,
        'easy': easy,
        'hard': hard,
      };

  factory Today.fromJson(Map j) {
    final t = Today(day: _i(j['day']), startedAt: _i(j['started']), slipStart: _ls(j['slip']));
    t.done = _i(j['done']);
    t.ok = _i(j['ok']);
    t.fail = _i(j['fail']);
    t.ms = _i(j['ms']);
    t.newSeen = _i(j['new']);
    t.seen.addAll(_ls(j['seen']));
    t.goalHit = _b(j['goal']);
    ((j['decks'] as Map?) ?? const {}).forEach((k, v) => t.decks['$k'] = _i(v));
    t.lastDeck = j['lastDeck'] as String?;
    t.run = _i(j['run']);
    t.bestRun = _i(j['bestRun']);
    t.easy = _i(j['easy']);
    t.hard = _i(j['hard']);
    return t;
  }

  Today copy() => Today.fromJson(toJson());
}

/// The engine's learned state about *you*.
class EngineState {
  EngineState({PersonalBaselines? baselines, GradeTuner? tuner, Calibration? calibration, this.weights})
      : baselines = baselines ?? PersonalBaselines(),
        tuner = tuner ?? GradeTuner(),
        calibration = calibration ?? Calibration();

  final PersonalBaselines baselines;
  final GradeTuner tuner;
  final Calibration calibration;

  /// Personalised FSRS-6 weights, once trained on your own reviews.
  List<double>? weights;
  int trainedAt = 0;
  int trainedOn = 0;
  double? lossBefore;
  double? lossAfter;

  Map<String, Object?> toJson() => {
        'base': baselines.toJson(),
        'tuner': tuner.toJson(),
        'calib': calibration.toJson(),
        'w': weights,
        'trainedAt': trainedAt,
        'trainedOn': trainedOn,
        'lossBefore': lossBefore,
        'lossAfter': lossAfter,
      };

  factory EngineState.fromJson(Map? j) {
    if (j == null) return EngineState();
    final e = EngineState(
      baselines: PersonalBaselines.fromJson(j['base'] as Map?),
      tuner: GradeTuner.fromJson(j['tuner'] as Map?),
      calibration: Calibration.fromJson(j['calib'] as Map?),
      weights: (j['w'] as List?)?.map((x) => (x as num).toDouble()).toList(),
    );
    e.trainedAt = _i(j['trainedAt']);
    e.trainedOn = _i(j['trainedOn']);
    e.lossBefore = _dn(j['lossBefore']);
    e.lossAfter = _dn(j['lossAfter']);
    return e;
  }
}

/// One swipe, in a standard review-log shape (RES-47 §5.5), exportable and used for training.
class ReviewLog {
  ReviewLog({
    required this.ts,
    required this.cardId,
    required this.deckId,
    required this.grade,
    required this.mode,
    required this.elapsedDays,
    this.rPred,
    this.sBefore,
    this.dBefore,
    required this.sAfter,
    required this.dAfter,
    required this.signals,
    required this.confidence,
    required this.automatic,
    this.reinsertAt,
  });

  final int ts;
  final String cardId;
  final String deckId;
  final int grade;

  /// flow · warmup · mix · practice · tutorial
  final String mode;

  /// Whole study days since the previous review; -1 for the first review.
  final int elapsedDays;
  final double? rPred;
  final double? sBefore;
  final double? dBefore;
  final double sAfter;
  final double dAfter;
  final Map<String, Object?> signals;
  final double confidence;
  final bool automatic;
  final int? reinsertAt;

  bool get ok => grade > 1;

  Map<String, Object?> toJson() => {
        'ts': ts,
        'card': cardId,
        'deck': deckId,
        'g': grade,
        'mode': mode,
        'el': elapsedDays,
        'r': rPred,
        'sb': sBefore,
        'db': dBefore,
        's': sAfter,
        'd': dAfter,
        'sig': signals,
        'c': double.parse(confidence.toStringAsFixed(3)),
        'auto': automatic,
        'n': reinsertAt,
      };

  factory ReviewLog.fromJson(Map j) => ReviewLog(
        ts: _i(j['ts']),
        cardId: _s(j['card']),
        deckId: _s(j['deck']),
        grade: _i(j['g'], 3),
        mode: _s(j['mode'], 'flow'),
        elapsedDays: _i(j['el'], -1),
        rPred: _dn(j['r']),
        sBefore: _dn(j['sb']),
        dBefore: _dn(j['db']),
        sAfter: _d(j['s']),
        dAfter: _d(j['d']),
        signals: Map<String, Object?>.from((j['sig'] as Map?) ?? const {}),
        confidence: _d(j['c']),
        automatic: _b(j['auto'], true),
        reinsertAt: (j['n'] as num?)?.toInt(),
      );
}
