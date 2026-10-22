"""Convert the prototype's hand-written decks (prototype/content.js) into content/decks/originals/*.json.

Run once: python tools/convert_prototype_content.py
Each pool row is "front | back | label | example" (label and example optional).
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
SRC = ROOT / "prototype" / "content.js"
OUT = ROOT / "content" / "decks" / "originals"

# pool key -> (id, name, mono, category, level, folder, description)
META = {
    "de_a1": ("de-a1-everyday", "German · A1 Everyday", "De", "lang", "A1", "German",
              "Everyday nouns with their gender, each in a short example sentence."),
    "de_basics": ("de-a1-basics", "German · A1 Basics", "De", "lang", "A1", "German",
                  "The everyday nouns, verbs and adjectives you meet first, each with an example sentence."),
    "de_a2": ("de-a2", "German · A2", "De", "lang", "A2", "German",
              "Words for appointments, flats, work and complaints: the vocabulary of getting things done."),
    "de_b1": ("de-b1", "German · B1", "De", "lang", "B1", "German",
              "Abstract words for arguing a point: advantages, effects, habits and responsibilities."),
    "de_num": ("de-numbers", "German · Numbers", "De", "lang", "A1", "German",
               "Count from one to a thousand, including the backwards tens like einundzwanzig."),
    "de_verbs": ("de-verbs", "German · Verbs", "De", "lang", "A1", "German",
                 "Sixteen verbs you use every day, the modal verbs included, each in a sentence."),
    "es_basics": ("es-basics", "Spanish · Basics", "Es", "lang", "A1", "Languages",
                  "Home, food, city and the phrases you need on day one, with example sentences."),
    "es_verbs": ("es-verbs", "Spanish · Verbs", "Es", "lang", "A1", "Languages",
                 "The verbs that carry most Spanish sentences, each in a real example."),
    "fr_ess": ("fr-essentials", "French · Essentials", "Fr", "lang", "A1", "Languages",
               "Greetings, time words and the four verbs everything else is built on."),
    "fr_food": ("fr-food", "French · Food", "Fr", "lang", "A1", "Languages",
                "Order, shop and cook: the food words of a French market and café."),
    "ar_alpha": ("ar-alphabet", "Arabic · Alphabet", "ع", "lang", "script", "Languages",
                 "All 28 letters with their names and sounds, including the heavy consonants."),
    "ar_greet": ("ar-greetings", "Arabic · Greetings", "ع", "lang", "phrases", "Languages",
                 "Greet, thank and take leave politely, with the replies people expect."),
    "en_idioms": ("en-idioms", "English · Idioms", "En", "lang", "B2", "Languages",
                  "Idioms native speakers use every week, each in a real sentence."),
    "py": ("python-syntax", "Python · Syntax", "Py", "code", "basics", "Coding",
           "The built-ins and syntax you look up most: slicing, comprehensions, context managers."),
    "git": ("git-commands", "Git · Commands", "Gi", "code", "basics", "Coding",
            "The everyday commands for staging, committing, branching and undoing."),
    "dart": ("dart-basics", "Dart · Basics", "Da", "code", "basics", "Coding",
             "Null safety, futures and the type system: what you need before writing Flutter."),
    "cpp": ("cpp-pointers", "C++ · Pointers", "C++", "code", "core", "Coding",
            "Addresses, references and smart pointers, one idea per card."),
    "bones": ("anatomy-bones", "Anatomy · Bones", "Bo", "med", "skeleton", "Medicine",
              "The major bones of the skeleton with their everyday names."),
    "pharm": ("pharm-basics", "Pharmacology · Basics", "Rx", "med", "classes", "Medicine",
              "Recognise a drug class from its name ending, with one example each."),
    "medpre": ("med-prefixes", "Medical Prefixes", "Mx", "med", "terms", "Medicine",
               "Decode unfamiliar medical words from the prefix at their start."),
    "capitals": ("world-capitals", "World Capitals", "Ca", "knowledge", "trivia", "Knowledge",
                 "The capitals that trip people up, because they are not the biggest city."),
    "elements": ("periodic-table", "Periodic Table", "Pt", "science", "core", "Science",
                 "Element symbols and names, from hydrogen to the metals you use every day."),
    "airport": ("airport-english", "Airport English", "Ai", "lang", "travel", "Travel",
                "Check-in, security and gate phrases, so nothing at the airport surprises you."),
    "ja": ("ja-survival", "Japanese · Survival", "日", "lang", "phrases", "Travel",
           "The polite phrases that get you through a first trip to Japan."),
    "hist": ("history-dates", "History · Key Dates", "Hi", "knowledge", "dates", "Knowledge",
             "The turning points of the last 1,500 years, one date per card."),
    "ancient": ("history-ancient", "History · Ancient World", "An", "knowledge", "dates", "Knowledge",
                "Pyramids to the fall of Rome: the dates that frame the ancient world."),
    "chords": ("guitar-chords", "Guitar · Chords", "Gu", "knowledge", "music", "Knowledge",
               "Open chord shapes written as fret numbers, low E string first."),
    "morse": ("morse-code", "Morse Code", "Mo", "knowledge", "code", "Knowledge",
              "Letters and the distress call in dots and dashes."),
}

POOL_RE = re.compile(r"^\s{2}(\w+): \{([^`]*)rows: `(.*?)`\s*\}", re.S | re.M)


def main() -> None:
    text = SRC.read_text(encoding="utf-8")
    OUT.mkdir(parents=True, exist_ok=True)
    total = 0
    for m in POOL_RE.finditer(text):
        key, head, rows = m.group(1), m.group(2), m.group(3)
        if key not in META:
            raise SystemExit(f"no metadata for pool {key}")
        lang = re.search(r"lang: '([^']+)'", head)
        kind = re.search(r"kind: '([^']+)'", head)
        tag = re.search(r"tag: '([^']+)'", head)
        cards = []
        for line in rows.strip().splitlines():
            parts = [p.strip() for p in line.split(" | ")]
            front, back = parts[0], parts[1]
            label = parts[2] if len(parts) > 2 and parts[2] else (tag.group(1) if tag else "")
            example = parts[3] if len(parts) > 3 else ""
            cards.append({"front": front, "back": back, "label": label, "example": example, "hook": ""})
        did, name, mono, cat, level, folder, desc = META[key]
        deck = {
            "id": did, "name": name, "mono": mono, "category": cat, "level": level,
            "lang": lang.group(1) if lang else None,
            "kind": kind.group(1) if kind else "text",
            "folder": folder, "description": desc, "origin": "originals",
            "cards": cards,
        }
        (OUT / f"{did}.json").write_text(json.dumps(deck, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        total += len(cards)
        print(f"{did:20} {len(cards):3} cards")
    print(f"{total} cards")


if __name__ == "__main__":
    main()
