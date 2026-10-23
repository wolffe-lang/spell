# spell

**A dictionary spell checker in wolf with suggestions by edit distance through a BK-tree, checked against a brute-force Levenshtein oracle — the fast index must agree with the slow truth on every query.**

---

## 1. What & why

`spell` reads text, flags words not in the dictionary, and for each flagged word lists every dictionary word within edit distance 1 (then 2), nearest first. The dictionary is the system word list (`/usr/share/dict/words`, about 235,000 entries on macOS). A naive suggester computes the distance to every word for every misspelling: 235,000 Levenshtein evaluations per query, seconds per word. A **BK-tree** (a metric tree over the edit distance) answers the same query by visiting a few hundred nodes.

The point of the project is the agreement test: for any query, the tree's answer set must equal the brute force's, exactly. A BK-tree that is subtly wrong (a bad triangle-inequality bound, an off-by-one on the radius) returns a plausible subset and nobody notices, except an oracle.

### What this exercises

A classic DP (Levenshtein with early exit), a metric-tree data structure built over an arena (no recursive enum), text tokenization with Unicode awareness (`'` inside words, case folding rules), a streaming line-oriented CLI, sorting with a composite key, and an oracle-driven test.

---

## 2. Background & core concepts

- **Levenshtein distance** `d(a, b)`: the minimum insertions, deletions and substitutions turning `a` into `b`. The DP uses two rows; with a cap `k`, stop when every cell in a row exceeds `k` (early exit).
- **Metric:** `d(a, c) <= d(a, b) + d(b, c)`. Hence a node `n` with children keyed by `d(n, child)` lets a query `q` with radius `k` skip every child whose key lies outside `[d(n, q) - k, d(n, q) + k]`.
- **BK-tree:** the root is the first word; insert `w` by walking: at node `n` with `k = d(n, w)`, go to child `k` if it exists else attach `w` there. Lookup walks the same way with the interval rule. Store nodes in a `List[Node]` with `children: List[(int, int)]` (key, node id) or two parallel lists.
- **Words:** a token is a maximal run of letters, with an apostrophe allowed between letters (`don't`); digits break tokens; case: a word is looked up as-is, then lower-cased, then with the first letter lower-cased (`The` → `the`); proper-noun capitalization in the dictionary (`Paris`) matches only the exact case or the all-caps form.

---

## 3. Functional requirements (numbered, testable)

- **FR-1** `spell [--dict FILE] [FILE|-]...` reads the text, prints one line per unknown word in order of first appearance: `LINE:COL: WORD` followed by `  → s1, s2, …` (up to `--max N`, default 8, nearest first, ties alphabetical) or `  → (no suggestions)`; exit 0 when no unknown words, 1 when some, 2 on usage or a missing dictionary.
- **FR-2** `--radius 1|2` (default 2): suggestions within that distance; distance-1 results always precede distance-2.
- **FR-3** `spell suggest WORD...` prints suggestions for the given words only (no file read).
- **FR-4** `spell check-index` builds the tree, then for 500 random dictionary words with one random edit applied (an insertion, a deletion, a substitution or a transposition) compares the tree's answer set at radius 2 against the brute-force set over the whole dictionary; prints `agree 500/500` and exits 0, or lists every disagreement and exits 1. (This is the oracle inside the tool; `test.sh` runs it.)
- **FR-5** The tree is built once per run from the dictionary (235k words in under 1.5 s on this Mac, measured) and answers a radius-2 query in under 10 ms median (measured by `spell bench`, FR-6).
- **FR-6** `spell bench` prints: build time, nodes visited per query (mean over 200 queries), median and p99 query time, and the brute-force time for one query, for comparison.
- **FR-7** Tokenization as §2: `don't` one word; `well-known` two words; `O'Brien` one word; digits end a token; `Paris` known, `paris` unknown with `Paris` suggested at distance 0 case-insensitively (reported as a capitalization hint `~ Paris` first).
- **FR-8** `--ignore FILE` adds words to the dictionary for this run; `--dict` replaces the system list.
- **FR-9** Non-UTF-8 input is refused with exit 2 and a message naming the line.

---

## 4. Interface / CLI spec

```
spell [--dict FILE] [--ignore FILE] [--radius N] [--max N] [FILE|-]...
spell suggest [--radius N] [--max N] WORD...
spell check-index [--dict FILE] [--seed N]
spell bench [--dict FILE]
spell --help
```

---

## 5. Architecture guidance (described, not prescribed)

- `lev.lu` — `distance(a, b) -> int` and `distance_capped(a, b, k) -> int` (returns `k+1` when exceeded); operate on `List[char]` (code points), not bytes, so `café` is four letters.
- `bk.lu` — `struct Tree { words: List[str], chars: List[List[char]], kids: List[List[int]], keys: List[List[int]] }`; `build(words) -> Tree`; `query(tree, word, k) -> List[(int, str)]` (distance, word) with a `visited` counter for `bench`.
- `tokens.lu` — `tokenize(line) -> List[(int, str)]` (column, word) by the rules in §2.
- `dict.lu` — load, case variants, the ignore list.
- `main.lu`, `*_test.lu` (distance on known pairs including Unicode, tokenization, tree agreement on a 500-word subset in-process).

---

## 6. Build

```
wolf build main.lu -o spell
wolf test .
./test.sh        # rows + check-index + a Python brute-force cross-check of 50 queries; exit 0 on pass
wolf fmt --check *.lu
```

---

## 7. Testing & acceptance

### 7.1 Rows

| row | check |
|---|---|
| L1 | `distance("kitten","sitting")` = 3; `("", "abc")` = 3; `("flaw","lawn")` = 2; `("café","cafe")` = 1 |
| L2 | `distance_capped("kitten","sitting", 2)` = 3 (exceeded), `…, 3` = 3 |
| T1 | tokenize `Don't stop O'Brien, well-known 42nd street.` → `Don't`, `stop`, `O'Brien`, `well`, `known`, `nd`, `street` with the right columns |
| S1 | `spell suggest recieve` → `receive` first |
| S2 | `spell suggest paris` → `~ Paris` first, then distance-1 words |
| S3 | `printf 'The quick brwon fox\n' \| spell -` → `1:11: brwon  → brown, …`, exit 1 |
| S4 | a text of known words → nothing, exit 0 |
| S5 | `--radius 1` on `brwon` lists only distance-1 words; `--max 3` caps the list |
| X1 | `spell check-index --seed 7` → `agree 500/500`, exit 0 |
| X2 | **Oracle:** `test.sh` runs a Python brute-force Levenshtein over the dictionary for 50 random misspellings and compares with `spell suggest --max 1000 --radius 2`: identical sets |
| B1 | `spell bench`: build < 1.5 s; median query < 10 ms; nodes visited per query < 3% of the dictionary |
| E1 | a file with a non-UTF-8 byte → `spell: FILE:LINE: not UTF-8`, exit 2 |

### 7.2 Definition of Done

1. `wolf build`, `wolf fmt --check`, `wolf test .` clean.
2. `./test.sh` exits 0: every row, X1 and X2 agreeing exactly.
3. The tree never returns a word the brute force would not, and never misses one.

## 8. Milestones

1. **M1** `lev.lu` with L1, L2 (Unicode-correct).
2. **M2** `dict.lu` + `tokens.lu` (T1); `spell` flagging unknown words without suggestions (S4).
3. **M3** brute-force suggestions (S1–S3, slow but right); `test.sh` with X2.
4. **M4** `bk.lu`; `check-index` (X1) agreeing; `bench` (B1).
5. **M5** `--ignore`, `--max`, `--radius`, E1.

## 9. Stretch goals

- Damerau (transposition as one edit) as `--damerau`, with the oracle updated.
- Frequency-ranked suggestions from a word-count file.
- A persistent on-disk index (`spell index > words.bk`) loaded in milliseconds.

## 10. Constraints & non-goals

- One directory, std only. No stemming, no grammar; the system word list is the whole truth.
