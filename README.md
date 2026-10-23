> **Built by wollf.** This program was written by [wollf-v7sf3](https://huggingface.co/wolffe-lang/wollf-v7sf3),
> a 27B model trained to write wolf, driven through opencode by the prompts in `prompts/`, with a human
> reviewer judging each phase and writing the next. Every claim below is pasted from the binary; the test
> script is the reason to trust it.

# spell

A dictionary spell checker that flags unknown words and suggests corrections by edit distance. Built in wolf with a trie index, verified against a brute-force Levenshtein oracle.

## Install

```
wolf build main.lu -o spell
```

Built with wolf 0.2.34 (wolfgang, pin 9da7bdc).

## Usage

Check a file:

```
$ printf 'The quick brwon fox\n' > t.txt
$ spell t.txt
1:11: brwon  → broon, argon, Arion, aroon, arson, bacon, baron, barton
```

Suggest for a word:

```
$ spell suggest brwon
brwon  → broon, argon, Arion, aroon, arson, bacon, baron, barton
```

With `--damerau` (brute force only — the trie walks Levenshtein distance):

```
$ spell suggest --damerau brwon
brwon  → broon, brown, argon, Arion, aroon, arson, bacon, baron
```

Verify the index (500 random edits, trie vs brute force):

```
$ spell check-index --seed 7
agree 500/500
```

Benchmark:

```
$ spell bench
build: 49 ms, 793015 nodes
queries: 200, visited mean: 18306 (2%), median: 18569 (2%), max: 26787 (3%)
query time: median 3 ms, p99 5 ms
brute-force: 42 ms for one query (4 results)
speedup: 14x (trie vs brute-force)
```

Help:

```
$ spell --help
Usage: spell [--dict FILE] [--ignore FILE] [--radius N] [--max N] [--damerau] [FILE|-]...
       spell suggest [--radius N] [--max N] [--damerau] WORD...
       spell check-index [--dict FILE] [--seed N]
       spell bench [--dict FILE] [--damerau]
       spell --help

  spell suggest: known words print 'WORD: known'.
  Capitalization hints are marked with ~ (e.g. 'paris' → '~ Paris').
  All-caps words are known if any dictionary word matches case-insensitively.
  Unknown all-caps words get the suggestions their lower-case form gets.
  Multi-file mode prefixes output with FILE: (e.g. 'file.txt:1:3: word').
  --damerau: use restricted Damerau-Levenshtein distance (optimal string alignment; transpositions count as 1 edit).
```

## Suggestion rules

Suggestions are dictionary words within edit distance `--radius N` (default 2), sorted by distance then case-insensitively. Up to `--max N` (default 8) are shown.

- **Tie-break:** words at the same distance are sorted case-insensitively; capitalized forms come first.
- **Capitalization hint:** if the query matches a dictionary word case-insensitively, it is prefixed with `~` and appears first (e.g. `paris` → `~ Paris`).
- **All-caps:** an all-caps token is known when any dictionary word equals it case-insensitively. An unknown all-caps token gets the suggestions its lower-case form gets.
- **`--damerau`:** uses restricted Damerau-Levenshtein distance (optimal string alignment), where transpositions count as one edit. This searches by brute force — the trie walks Levenshtein distance only.

## Exit codes

- **0:** no unknown words (or `--help`, or `check-index` agreement).
- **1:** unknown words found.
- **2:** usage error, missing dictionary, or non-UTF-8 input.

## Options

- `--dict FILE` — replace the system dictionary (`/usr/share/dict/words`). Supported by the file mode, `check-index`, and `bench`.
- `--ignore FILE` — add words to the dictionary for this run. Supported by the file mode only.
- `--radius N` — maximum edit distance (default 2).
- `--max N` — maximum suggestions per word (default 8).

`spell suggest` does not take `--dict` or `--ignore`; it always uses the system dictionary.

## How the index works

The trie stores every dictionary word as a path from the root, with nodes in parallel lists (arena style). A query walks the trie, maintaining a DP row of edit distances against the query string. At each node, the row is updated by comparing the edge character against each query character. Nodes whose row minimum exceeds the radius are pruned. The trie visits about 2% of its nodes per query (18k of 793k). The BK-tree was replaced because its median query time (38ms, measured at 0.1.0) exceeded the 10ms bar; the trie is 14x faster (3ms vs 42ms, measured at 0.2.1) and visits 2.4x fewer nodes (18k vs 43k).

## Tests

```
wolf test .           # 12 tests, including L3 (Damerau) and trie vs brute force agreement
./test.sh             # 32 rows: L1–E1, D1, edges, hints, --damerau, X1–X3d, caps, suggest_dict (exact output comparison)
```

The oracle (`oracle.py`) is a Python brute-force Levenshtein that scans the entire dictionary for each query. `test.sh` compares its output with `spell suggest` on 50 random misspellings (X2), 50 with `--damerau` (X2d), and checks the ordered first 8 suggestions match (X3, X3d).

## Measured numbers

macOS, wolf 0.2.34, 2026-10-23:

| metric | value |
|---|---|
| build time | 49 ms |
| nodes | 793,015 |
| visited per query | 18,306 (2%) |
| median query time | 3 ms |
| p99 query time | 5 ms |
| brute-force time | 42 ms |
| speedup | 14x |

## Files

- `main.lu` — CLI entry, argument dispatch, main loop
- `lev.lu` — Levenshtein and Damerau-Levenshtein distance
- `trie.lu` — trie construction and search
- `tokens.lu` — word tokenization
- `dict.lu` — dictionary loading, case variants, ignore list
- `suggest.lu` — brute-force suggestions
- `agree_test.lu` — trie vs brute force agreement test
- `dict_test.lu` — dictionary loading tests
- `lev_test.lu` — distance function tests (L1, L2, L3)
- `tokens_test.lu` — tokenization tests (T1)
- `trie_test.lu` — trie operation tests
- `oracle.py` — Python brute-force oracle
- `test.sh` — test harness (27 rows)
- `SPEC.md` — the specification
- `REVIEW.md` — per-file review
- `CHANGELOG.md` — version history
- `README.md` — this document
- `prompts/` — the prompts that drove this build
- `LICENSE` — Apache License 2.0
- `.gitignore` — build artifacts

Licensed under the Apache License 2.0 (`LICENSE`).
