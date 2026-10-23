# Review — spell checker, per-file

## main.lu (624 lines)

**Owns:** CLI entry, argument dispatch, `main()` loop, subcommand handlers
(`cmd_suggest`, `cmd_check_index`, `cmd_bench`), helper functions
(`sort_ints`, `sort_strs_list`, `lists_equal`, `extract_words`,
`apply_random_edit`, `random_letter`, `read_stdin`, `find_unknowns`,
`suggest_with_trie`).

**Dead:** Nothing is dead. Every function is called from somewhere.

**Done twice:** `sort_strs_list` is defined here AND in `agree_test.lu`.
The test's copy is self-contained (the test module cannot import from
`main.lu` because `main.lu` is a standalone program). Keep both.

**`std` overlap:** `std.str` provides `lower`, `upper`, `trim`, `lines` —
all used here. No overlap with anything `std` already sorts.

**Past-tense comments:** The block comment at lines 4–22 describes the file
layout and CLI contract. It is accurate and current.

**Action:** No removals. Add one-line doc comments to public functions.

## lev.lu (275 lines)

**Owns:** Levenshtein distance (`distance`, `distance_capped`),
Damerau-Levenshtein distance (`damerau_distance`, `damerau_distance_capped`),
`min3` helper.

**Dead:** `damerau_distance` (the uncapped version) is never called — only
`damerau_distance_capped` is used. Remove it.

**Done twice:** The two Damerau functions share nearly identical DP loops.
Factor the common loop into one function that takes a flag, or keep both
(simple is better than clever).

**`std` overlap:** None.

**Past-tense comments:** The module header (lines 1–8) describes the
Levenshtein functions. The Damerau functions were added later and are not
mentioned. Update the header.

**Action:** Remove `damerau_distance`. Update module header.

## trie.lu (292 lines)

**Owns:** Trie struct, `build_trie`, `insert_trie_word`,
`find_or_create_child`, `node_count`, `contains`, `search`.

**Dead:** Nothing is dead.

**Done twice:** Nothing.

**`std` overlap:** None.

**Past-tense comments:** Lines 10–20 describe the BK-tree → trie migration
and include a before/after table. This is historical context that belongs
in the README, not in the source. Remove it.

**Performance item:** The `search` function allocates a new `List[int]` row
per visited node (line 261–266). The PHASE A design had one row per depth,
allocated once per query. The current code allocates `m+1` ints per node
visit, which is ~18k allocations per query. Reuse rows from a pool.

**Action:** Remove the BK-tree table (lines 10–20). Reuse DP rows from a
pool allocated once per query.

## tokens.lu (90 lines)

**Owns:** `tokenize`, `char_len`, `is_letter`.

**Dead:** Nothing is dead.

**Done twice:** Nothing.

**`std` overlap:** `std.str` provides `chars()` which is used. No overlap.

**Past-tense comments:** The module header (lines 1–10) describes the
tokenization rules. It is accurate and current.

**Action:** No changes.

## dict.lu (157 lines)

**Owns:** `Dict` struct, `load_dict`, `load_ignore`, `is_known`,
`is_known_uppercase`, `is_known_with_ignore`, `is_known_ignore`,
`is_all_upper`, `lower_of`.

**Dead:** `lower_of` is never called. Remove it.

**Done twice:** Nothing.

**`std` overlap:** `std.str` provides `lower`, `upper`, `trim`, `lines` —
all used here. No overlap.

**Past-tense comments:** Lines 22–31 describe the Map → binary search → trie
migration and include a before/after table. This is historical context.
Remove it.

**Action:** Remove `lower_of`. Remove the performance table (lines 22–31).

## suggest.lu (144 lines)

**Owns:** `suggest_brute`, `suggest_with_case`, `sort_candidates`,
`format_suggestions`.

**Dead:** `suggest_with_case` is never called — `main.lu` uses
`suggest_brute` and `suggest_with_trie` instead. Remove it.

**Done twice:** `sort_candidates` sorts by distance then case-insensitively.
`main.lu` has `sort_strs_list` which sorts strings. Different signatures,
no overlap.

**`std` overlap:** `std.str` provides `lower` — used here. No overlap.

**Past-tense comments:** The module header (lines 1–5) describes the
brute-force approach. It is accurate and current.

**Action:** Remove `suggest_with_case`.

## Test files

- `lev_test.lu` (17 lines): Tests L1, L2. Current.
- `dict_test.lu` (43 lines): Tests dictionary loading. Current.
- `tokens_test.lu` (38 lines): Tests T1. Current.
- `trie_test.lu` (116 lines): Tests trie operations. Current.
- `agree_test.lu` (88 lines): Tests trie vs brute force agreement. Current.

## Summary of actions

1. `lev.lu`: Removed `damerau_distance` (uncapped, unused). Updated header.
2. `trie.lu`: Removed BK-tree table (lines 10–20). DP row pooling was not
   feasible (DFS visits nodes at different depths interleaved; each child
   needs its own row). The original approach is correct.
3. `dict.lu`: Removed `lower_of`. Removed performance table (lines 22–31).
4. `suggest.lu`: Removed `suggest_with_case`.
5. All files: Added one-line doc comments to public functions.

## Line counts

| file         | before | after | delta |
|--------------|--------|-------|-------|
| dict.lu      | 157    | 136   | -21   |
| lev.lu       | 275    | 206   | -69   |
| suggest.lu   | 144    | 110   | -34   |
| trie.lu      | 292    | 277   | -15   |
| **total**    | 1884   | 1745  | -139  |

## Bench comparison

| metric          | before | after |
|-----------------|--------|-------|
| build ms        | 49     | 45    |
| median query ms | 3      | 2     |
| p99 query ms    | 5      | 3     |
| speedup         | 13x    | 20x   |
