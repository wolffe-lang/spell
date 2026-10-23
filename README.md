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
$ spell FILE
1:11: brwon  → brown, broon, argon, Arion, aroon, arson, bacon, baron
```

Suggest for a word:

```
$ spell suggest brwon
brwon  → brown, broon, argon, Arion, aroon, arson, bacon, baron
```

Verify the index (500 random edits, trie vs brute force):

```
$ spell check-index --seed 7
agree 500/500
```

Benchmark:

```
$ spell bench
build: 47 ms, 793015 nodes
queries: 200, visited mean: 18306 (2%), median: 18569 (2%), max: 26787 (3%)
query time: median 2 ms, p99 4 ms
brute-force: 40 ms for one query (4 results)
speedup: 20x (trie vs brute-force)
```

## Suggestion rules

Suggestions are dictionary words within edit distance `--radius N` (default 2), sorted by distance then case-insensitively. Up to `--max N` (default 8) are shown.

- **Tie-break:** words at the same distance are sorted case-insensitively; capitalized forms come first.
- **Capitalization hint:** if the query matches a dictionary word case-insensitively, it is prefixed with `~` and appears first (e.g. `paris` → `~ Paris`).
- **`--damerau`:** uses Damerau-Levenshtein distance, where transpositions count as one edit (e.g. `recieve` → `receive` at distance 1).

## Exit codes

- **0:** no unknown words (or `--help`, or `check-index` agreement).
- **1:** unknown words found.
- **2:** usage error, missing dictionary, or non-UTF-8 input.

## Options

- `--dict FILE` — replace the system dictionary (`/usr/share/dict/words`).
- `--ignore FILE` — add words to the dictionary for this run.
- `--radius N` — maximum edit distance (default 2).
- `--max N` — maximum suggestions per word (default 8).

## How the index works

The trie stores every dictionary word as a path from the root, with nodes in parallel lists (arena style). A query walks the trie, maintaining a DP row of edit distances against the query string. At each node, the row is updated by comparing the edge character against each query character. Nodes whose row minimum exceeds the radius are pruned. The trie visits about 2% of its nodes per query (18k of 793k), compared to the BK-tree's 18% (43k of 236k). The BK-tree was replaced because its median query time (38ms) exceeded the 10ms bar; the trie is 12x faster (3ms vs 38ms) and visits 2.4x fewer nodes.

## Tests

```
wolf test .           # 11 tests, including trie vs brute force agreement
./test.sh             # 25 rows: L1–E1, D1, edges, hints, --damerau, X1, X2, X2d
```

The oracle (`oracle.py`) is a Python brute-force Levenshtein that scans the entire dictionary for each query. `test.sh` compares its output with `spell suggest` on 50 random misspellings (X2) and 50 with `--damerau` (X2d).

## Measured numbers

macOS, wolf 0.2.34, 2026-10-23:

| metric | value |
|---|---|
| build time | 47 ms |
| nodes | 793,015 |
| visited per query | 18,306 (2%) |
| median query time | 2 ms |
| p99 query time | 4 ms |
| brute-force time | 40 ms |
| speedup | 20x |

## Files

- `main.lu` — CLI entry, argument dispatch, main loop
- `lev.lu` — Levenshtein and Damerau-Levenshtein distance
- `trie.lu` — trie construction and search
- `tokens.lu` — word tokenization
- `dict.lu` — dictionary loading, case variants, ignore list
- `suggest.lu` — brute-force suggestions
- `oracle.py` — Python brute-force oracle
- `test.sh` — test harness (25 rows)
- `SPEC.md` — the specification
- `REVIEW.md` — per-file review
- `CHANGELOG.md` — version history
- `prompts/` — the prompts that drove this build
- `LICENSE` — Apache-2.0
- `.gitignore` — build artifacts

Licensed under Apache-2.0.
