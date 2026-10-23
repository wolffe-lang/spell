# Changelog

## 0.2.1

- `check-index --damerau` removed: it compared brute force with brute force and checked nothing.
- `spell suggest` does not take `--dict` or `--ignore` (documented).
- Ordered comparison rows X3/X3d: the first 8 suggestions must match the oracle's first 8.
- All-caps words are known when any dictionary word matches case-insensitively.
- Unknown all-caps words get the suggestions their lower-case form gets.
- The file mode now accepts `--damerau` (uses brute force).
- `spell suggest` rejects unknown options with exit 2.
- Test rows compare exact output, not just grep patterns.
- LICENSE is the official Apache License 2.0 text (SHA-256: cfc7749b...).

## 0.2.0

- Trie index replaces the BK-tree (14x faster, 2.4x fewer nodes visited).
- Sorted-dictionary fix: binary search on sorted `List[str]` replaces `Map` lookup (the runtime's Map is a linear scan, wolf-lang#894).
- Restricted Damerau-Levenshtein distance (`--damerau`, optimal string alignment): transpositions count as one edit.
- Edge cases: empty file, no trailing newline, CRLF, Unicode, apostrophes.
- Capitalization hints (`~ Paris`), all-caps handling (`PARIS` known).
- Case-insensitive tie-break in suggestions.
- `bench --damerau` (Damerau brute force is slower: 148ms vs 40ms).

## 0.1.0

- First build: BK-tree index, Levenshtein distance, tokenization.
- `spell FILE`, `spell suggest`, `spell check-index`, `spell bench`.
- Python brute-force oracle (`oracle.py`).
- `test.sh` with 25 rows (L1–E1, D1, edges, hints, X1, X2).

## Not done

- No stemming, no grammar; the system word list is the whole truth.
- No frequency-ranked suggestions.
- No persistent on-disk index.
