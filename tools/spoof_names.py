"""Subtle, deterministic name spoofing: one or two letters off the real name."""
import random
import re

VOWELS = "aeiouy"

# (pattern, replacement) — regexes on the lowercase name. Order doesn't matter;
# every rule that applies is a candidate and one is picked per name.
SUFFIX_RULES = [
    (r"son$", "sen"), (r"sen$", "son"), (r"ski$", "sky"), (r"sky$", "ski"),
    (r"ov$", "off"), (r"ev$", "eff"), (r"in$", "yn"), (r"er$", "ar"), (r"ar$", "er"),
    (r"ett$", "et"), (r"man$", "mann"), (r"mann$", "man"), (r"ton$", "tin"),
    (r"ey$", "ie"), (r"ie$", "ey"), (r"y$", "ie"), (r"ck$", "k"), (r"in$", "en"),
    (r"en$", "an"), (r"is$", "ys"), (r"es$", "ez"), (r"ez$", "es"), (r"ch$", "tch"),
    (r"ll$", "l"), (r"a$", "ah"), (r"o$", "oh"),
]
INNER_RULES = [
    (r"ph", "f"), (r"ck", "k"), (r"c(?=[aou])", "k"), (r"k(?=[aou])", "c"),
    (r"(?<=.)y", "i"), (r"(?<=.)i(?=[^aeiou])", "y"), (r"(?<=[aeiou])s(?=[aeiou])", "z"),
    (r"ff", "f"), (r"tt", "t"), (r"ll", "l"), (r"nn", "n"), (r"rr", "r"), (r"ss", "s"),
    (r"mm", "m"), (r"ou", "oo"), (r"ie", "ei"), (r"ei", "ie"), (r"(?<![st])ch", "tch"),
    (r"w", "v"), (r"(?<=.)th", "t"), (r"qu", "kw"), (r"x", "ks"), (r"z", "s"),
    (r"ae", "ea"), (r"au", "ow"),
]
# Gentle vowel swaps in the middle of the name.
VOWEL_SWAP = {"a": "e", "e": "a", "o": "u", "u": "o", "i": "e"}


def _match_case(src: str, out: str) -> str:
    return out[:1].upper() + out[1:] if src[:1].isupper() else out


def _candidates(word: str) -> list[str]:
    low = word.lower()
    outs = set()
    for pat, rep in SUFFIX_RULES + INNER_RULES:
        for m in re.finditer(pat, low):
            outs.add(low[:m.start()] + rep + low[m.end():])
    for i in range(1, len(low) - 1):
        if low[i] in VOWEL_SWAP and low[i - 1] not in VOWELS and low[i + 1] not in VOWELS:
            outs.add(low[:i] + VOWEL_SWAP[low[i]] + low[i + 1:])
    outs.discard(low)
    # No tripled letters, keep it readable.
    return sorted(o for o in outs if not re.search(r"(.)\1\1", o) and len(o) >= 2)


def _spoof_word(word: str, rng: random.Random) -> str:
    # Keep inner capitals: McDavid -> Mc + David, MacKinnon -> Mac + Kinnon.
    m = re.match(r"^(Mc|Mac|De|Di|Da|La|Le|Van)([A-Z].+)$", word)
    if m:
        return m.group(1) + _spoof_word(m.group(2), rng)
    if len(word) < 2 or not word.isascii() and not any(c.isascii() for c in word):
        return word
    cands = _candidates(word)
    if not cands:
        return word + "e"
    return _match_case(word, rng.choice(cands))


def _spoof_part(name: str, rng: random.Random) -> str:
    # Handle "Van Riemsdyk", "Ekman-Larsson", "O'Reilly": change the longest piece.
    pieces = re.split(r"([ \-'])", name)
    idx = max(range(0, len(pieces), 2), key=lambda i: len(pieces[i]))
    pieces[idx] = _spoof_word(pieces[idx], rng)
    return "".join(pieces)


def spoof_name(first: str, last: str, seed: int, taken: set[str]) -> tuple[str, str]:
    rng = random.Random(seed)
    for attempt in range(40):
        f = _spoof_part(first, rng) if attempt < 20 else _spoof_part(_spoof_part(first, rng), rng)
        l = _spoof_part(last, rng)
        # Long surnames can take a second tweak and still read as a nod.
        if len(last) >= 8 and rng.random() < 0.3:
            l = _spoof_part(l, rng)
        if f"{f} {l}" not in taken and l.lower() != last.lower():
            return f, l
    return f, l + "s"
