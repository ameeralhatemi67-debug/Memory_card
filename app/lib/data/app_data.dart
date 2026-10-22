import 'models.dart';

/// Everything Memory Card knows, in memory. The store persists it; the engine reads and changes it.
class AppData {
  AppData({
    List<Folder>? folders,
    Map<String, Deck>? decks,
    Map<String, CardItem>? cards,
    Settings? settings,
    Profile? profile,
    this.today,
    EngineState? engine,
    List<String>? recentFolders,
    this.currentFolderId,
    this.lastDeckId,
    Set<String>? shopPins,
    Map<String, String>? shopAdded,
    this.onboarded = false,
    Set<String>? coach,
    int? createdAt,
    this.clockOffset = 0,
  })  : folders = folders ?? <Folder>[],
        decks = decks ?? <String, Deck>{},
        cards = cards ?? <String, CardItem>{},
        settings = settings ?? Settings(),
        profile = profile ?? Profile(since: createdAt ?? DateTime.now().millisecondsSinceEpoch),
        engine = engine ?? EngineState(),
        recentFolders = recentFolders ?? <String>[],
        shopPins = shopPins ?? <String>{},
        shopAdded = shopAdded ?? <String, String>{},
        coach = coach ?? <String>{};

  final List<Folder> folders;
  final Map<String, Deck> decks;
  final Map<String, CardItem> cards;
  Settings settings;
  Profile profile;
  Today? today;
  EngineState engine;

  /// The last folders touched, most recent first (the drawer shows their deck pills).
  List<String> recentFolders;
  String? currentFolderId;
  String? lastDeckId;

  /// Shop favourites.
  final Set<String> shopPins;

  /// Catalogue id → library deck id, for decks added from the shop.
  final Map<String, String> shopAdded;
  bool onboarded;

  /// Coach marks already shown.
  final Set<String> coach;

  /// Developer time travel (Settings › Lab): added to the real clock.
  int clockOffset;

  int now() => DateTime.now().millisecondsSinceEpoch + clockOffset;

  Folder? folderOf(String deckId) {
    for (final f in folders) {
      if (f.deckIds.contains(deckId)) return f;
    }
    return null;
  }

  Folder? folderById(String? id) {
    if (id == null) return null;
    for (final f in folders) {
      if (f.id == id) return f;
    }
    return null;
  }

  /// Decks that count for the day (not archived).
  Iterable<Deck> get activeDecks sync* {
    for (final f in folders) {
      if (f.isArchive) continue;
      for (final id in f.deckIds) {
        final d = decks[id];
        if (d != null) yield d;
      }
    }
  }

  Iterable<CardItem> cardsOf(Deck d) sync* {
    for (final id in d.cardIds) {
      final c = cards[id];
      if (c != null) yield c;
    }
  }
}
