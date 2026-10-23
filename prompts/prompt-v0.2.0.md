# spell v0.2.0 — the index redesigned (a phased series, low give-away at the code level)

Paste one phase at a time into the session that holds the current `spell` (the BK-tree build with the sorted
dictionary lists). The reviewer read your stop in FOLLOW-UP 1 and agrees with your conclusion: a plain BK-tree
over Levenshtein visits 40,000 nodes at radius 2 on this dictionary and no root choice changes that; at
0.7–0.9 µs a visit the median cannot reach 10 ms. The structure is wrong for the bar, not your code. v0.2.0
replaces the index. Everything else you built stays: the distance, the tokens, the sorted dictionary lists,
the CLI, the Python oracle, `check-index`, `test.sh`.

**The architecture decision (made by the reviewer, so you do not have to):** the index is a **trie over the
dictionary's code points, searched by walking it with a Levenshtein DP row**. The idea, in one paragraph: in
the brute force you compute a full DP table for every word. Words that share a prefix share the first rows of
that table. A trie makes the sharing explicit: every trie node is one prefix, and one DP row (the distances
from that prefix to every prefix of the query) belongs to it, computed from its parent's row in O(|query|).
When every cell of a node's row is greater than the radius, nothing below that node can be within the radius,
so the whole subtree is skipped. At a node that ends a word, the last cell of its row is that word's distance.
That is the entire algorithm; the pruning is exact (the oracle will agree or it is a bug), and on an English
dictionary at radius 2 it touches a few thousand nodes, not forty thousand. It is also how the literature
answers this exact problem, so a stranger reading `trie.lu` will recognise it.

**Standing rules for every phase.** One directory, one module, one `main`. No `Map` with more than a few
thousand entries anywhere (wolf-lang#894). No allocation inside the search: every list the walk needs is made
once per query (or once per index) and reused. The brute force stays the oracle and `check-index` must read
`agree 500/500` before the new index takes the user path. Keep the before/after table in the index file's
header growing (build ms, nodes in the index, nodes visited mean/median/max, median ms, p99 ms, per-visit µs).
Stop at the end of each phase and paste the last lines and statuses.

---

### PHASE A — The design note and the prediction (nothing built)

Write `trie.lu` as a header comment only: the node layout you will use (think about what an arena of one
million nodes costs when each node owns a `List`, and what a representation with no per-node lists looks like:
parallel `List[int]`s indexed by node id, where a node knows its first child and its next sibling), how a word
is inserted so that siblings stay ordered (what does inserting in dictionary order buy you?), how the walk
keeps one DP row per depth without allocating (one `List[int]` of `(max depth + 1) × (|query| + 1)` cells made
once per query, or once per index with the longest query it will accept), how the walk visits children (an
explicit stack of node ids, not recursion), the pruning test (the row's minimum against the radius; where does
the minimum come for free?), and how a result is reported (the word's index, its distance).

Then the prediction, as numbers: the node count of the trie for 235,976 words (count the distinct prefixes if
you want to be exact; estimate from the average word length if not), the build time, the nodes visited for a
radius-2 query, the per-visit cost, and the median. Commit nothing else in this phase.

**Verify:** `trie.lu` holds the header and compiles as an empty module; the prediction is in it with a date.

--- END PHASE A ---

---

### PHASE B — The trie, built and tested (no search yet)

`trie.lu`: `build(words: List[str]) -> Trie` over the sorted word list; `node_count(t)`; a way to walk one
word down the trie and answer whether it is present (`contains(t, word)`), which is the unit test's handle
and also a second `is_known` the dictionary can use later. Tests in `trie_test.lu`: every dictionary word is
found; `"kittenz"` is not; the empty string's case; the node count equals your PHASE A count or you explain
the difference; `café` is four code points deep.

Measure the build time; if it is over 1.5 s, say where the time goes before changing anything (how many
times is each word's code points decoded? is the sibling search linear and how long are sibling lists at the
root?).

**Verify:** `wolf test .` green with the new tests; build under 1.5 s printed by a temporary `spell bench`
line; `wolf fmt --check *.lu`.

--- END PHASE B ---

---

### PHASE C — The walk, and the oracle

`search(t, query, k) -> List[(int, str)]` by the design of PHASE A, with a `visited` counter. Wire it into
`check-index` **beside** the BK-tree first: the command compares brute force, BK-tree and trie on the same
500 queries and reports all three agreements. Only when it reads `agree 500/500` for the trie does the user
path (`spell FILE`, `spell suggest`) switch to it. Then `bench` reports the trie's numbers.

**Verify:** `./spell check-index --seed 7` → `agree 500/500` for the trie (and still for the BK-tree);
`./spell bench`: nodes visited mean, median, max; median query under 10 ms; per-visit µs; `./test.sh` exits
0; the header table has the new row.

--- END PHASE C ---

---

### PHASE D — One index

Delete `bk.lu` and every reference to it (the reviewer wants one index in a published tool; the BK-tree's
measurements stay in `trie.lu`'s header table as the "before" row, with a sentence saying why it was
replaced). `check-index` compares brute force and trie. `bench` prints: build time, node count, nodes visited
(mean/median/max over 200 queries), median and p99 query time, brute-force time for one query, and the
speedup. README (the user README of FOLLOW-UP 8, when you get there) describes the trie, not the BK-tree.

**Verify:** `grep -ri bk *.lu` finds nothing; `wolf build`, `wolf fmt --check`, `wolf test .`, `./test.sh`
clean; `./spell bench` pasted in full.

--- END PHASE D ---

---

### PHASE E — The rest of the follow-ups

FOLLOW-UP 2 (the `~` hint, `PARIS`, a known word in `suggest`), 3 (input edges and E1's line), 5 (the
case-insensitive tie-break and `--damerau`, with the oracle taking the flag: think about what a transposition
does to the DP row recurrence in the trie walk; it needs the grandparent's row), 6 (`test.sh` as the proof,
50 oracle queries both ways, a scratch directory, every row by id), 7 (a stranger's read, `REVIEW.md`) and 8
(ship it: README, SPEC.md, CHANGELOG with v0.2.0's entry naming the index change, LICENSE, the honesty line)
from `prompt-followup.md`, in that order, one at a time, each with its own verify.

--- END PHASE E ---
