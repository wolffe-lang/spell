# Changelog

## 0.2.0

- Trie index replaces the BK-tree (12x faster, 2.4x fewer nodes visited).
- Sorted-dictionary fix: binary search on sorted `List[str]` replaces `Map` lookup (the runtime's Map is a linear scan, wolf-lang#894).
- Damerau-Levenshtein distance (`--damerau`): transpositions count as one edit.
- Edge cases: empty file, no trailing newline, CRLF, Unicode, apostrophes.
- Capitalization hints (`~ Paris`), all-caps handling (`PARIS` known).
- Case-insensitive tie-break in suggestions.
- `check-index --damerau` (50 queries, brute force vs brute force).
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
