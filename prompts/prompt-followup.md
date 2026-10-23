# spell — follow-ups after v3 (low give-away)

Paste these one at a time into the same session (or a fresh one in the same `vN/` directory
after PHASE 5 passed). Each follow-up names what a reviewer saw, the bar it must meet, and the
questions to think through. It does not say how. Do only the current follow-up, keep every
earlier verification passing, then stop and paste the last lines and statuses. One directory,
one wolf module, one `main`.

The goal: a `spell` we would publish under wolffe-lang as a tool built by wollf. "Works" is not
the bar; "a stranger installs it, reads its README, runs `./test.sh`, and trusts it" is.

---

### FOLLOW-UP 1 (revised 2026-10-23) — The index is correct but slow (B1), and what the reviewer found

The reviewer ran your first pass at this and read your `bk.lu` header: the alphabetical root, the
length-6 root, the shuffle that made it worse, the capped distance that broke the interval. You stopped at
16 % of nodes visited and a 31 ms median and wrote that this is the structure's ceiling. Two things to know
before you go again:

1. **The reviewer measured the compiler's `Map`.** 236,000 `map.set` calls take 29 s and 236,000 `map.has`
   calls take 34 s on this machine: the runtime's map is a linear scan (it says so in its own source, and it
   is now filed as wolf-lang#894). That is the 47–60 s your `spell` spends before it reads a word, and the
   55–165 µs you measured per `is_known`. It is not your code's fault and it will not be fixed in this
   session. So: **no `Map` with more than a few thousand entries anywhere in spell.** The dictionary is
   sorted on disk already; a `List[str]` kept sorted and a binary search is 18 comparisons for 236k words.
   The case-insensitive lookup is a second sorted list of lowered words, built once. Do this first and
   measure `./spell suggest hello` end to end: it should be under 1.5 s again.
2. **The 3 % bar was the spec's mistake; the 10 ms bar is not.** A plain BK-tree over Levenshtein at
   radius 2 on an English dictionary visits roughly 15–20 % of its nodes, as you found. The bar that matters
   to a user is the time. Think about where your 31 ms goes: 40,000 visits at under a microsecond each
   would be 30 ms, and a visit today calls `distance`, which calls `chars()` on both words and allocates two
   lists per call. The README's §5 gave the tree a `chars: List[List[char]]` field for exactly this reason.
   What would a visit cost if every dictionary word were decoded once at build time, the query decoded once,
   and the DP ran over two rows the walk allocates once and reuses? Predict the per-visit cost, then measure
   it. Also: a word whose length differs from the query's by more than the radius can never be within it;
   where in the walk is that check free?
3. If, after 1 and 2, the median is still over 10 ms, say so with the numbers and stop; the reviewer will
   decide whether a different index (a trie walked with the DP row, which visits a few thousand nodes
   instead of forty thousand) replaces the BK-tree or sits beside it. Do not build it unprompted.

Write your answers to the questions in 2 as the header of `bk.lu`, replacing the previous header's
conclusions where they were wrong, and keep the before/after table (build ms, visited mean, median ms,
p99 ms, per-visit µs) growing.

**Verify:** `./spell suggest hello` under 1.5 s wall; `./spell bench` build under 1.5 s and median query
under 10 ms, or the stop in 3 with the per-visit number; `./spell check-index --seed 7` still
`agree 500/500` and under 30 s; `./test.sh` exits 0.

--- END FOLLOW-UP 1 ---

---

### FOLLOW-UP 2 — The user path lost things the brute-force path had (FR-7)

When the tree replaced the scan, three behaviours went with it. The reviewer saw:

- `./spell suggest paris` prints `paris  → Paris, baris, …`. README FR-7 and S2 want the
  capitalization hint marked: `~ Paris` first. There is code in `suggest.lu` that writes `~`;
  trace from `main` which function the user path reaches and which it no longer does. Dead code
  is a bug waiting to be trusted.
- `./spell suggest PARIS` prints `(no suggestions)`. FR-7 says the all-caps form of a dictionary
  proper noun is known. Where should that rule live so that both `spell FILE` and `spell suggest`
  obey it?
- `./spell suggest Paris` lists `Paris` itself at the head of its own suggestions. What should
  `suggest` say about a word the dictionary knows? Decide, document it in `--help`, and make the
  check path and the suggest path agree.

**Verify:** S2 → `paris  → ~ Paris, …` (then the distance-1 words); `suggest PARIS` treats it as
known; `suggest Paris` does not suggest `Paris` to itself; `printf 'paris\n' | ./spell -` shows the
same hint with its column; X1, X2, `wolf test .`, `./test.sh` unchanged and green.

--- END FOLLOW-UP 2 ---

---

### FOLLOW-UP 3 — Input edges (FR-9, E1, FR-1)

- A file with a non-UTF-8 byte answers `spell: cannot read bad.txt: utf8`, exit 2. README E1
  wants `spell: FILE:LINE: not UTF-8`. The error you get back from `std.fs` carries no line; where
  in your pipeline is the line number known, and what has to change for the message to carry it?
- Try each of these and decide what `spell` should do before you look at what it does: an empty
  file; a file whose last line has no newline; CRLF line endings; a line of 100,000 characters;
  `spell -` with nothing on stdin; several files on one command line (do line numbers restart per
  file, and does the output name the file?); a word at the very end of a file; `'tis` and `dogs'`
  (an apostrophe at a word's edge); `café` (is its column counted in code points or bytes, and
  which does the README's `LINE:COL` mean?).
- Write each as a row in `test.sh` with the exact expected output, so the decision is recorded.

**Verify:** E1 → `spell: bad.txt:1: not UTF-8`, exit 2; every new row in `test.sh` with its
expected bytes; `./test.sh` exits 0.

--- END FOLLOW-UP 3 ---

---

### FOLLOW-UP 4 (revised 2026-10-23) — The dictionary lookup, retired into FOLLOW-UP 1

The `Map` you built in the first pass is the runtime's linear scan (wolf-lang#894; see FOLLOW-UP 1,
point 1), which is why the 3,000-word file took 84 s and startup took a minute. The sorted list with a
binary search from FOLLOW-UP 1 is the whole of this follow-up. One check remains:

**Verify:** the 3,000-word file (`awk 'NR%80==0' /usr/share/dict/words | head -3000 | tr '\n' ' '`) checks in
under 100 ms beyond the build; `./spell one-word.txt` under 1.5 s wall; `./spell bench` build under 1.5 s;
T1, S4, FR-8 rows green.

--- END FOLLOW-UP 4 ---

---

### FOLLOW-UP 5 — Ordering, and the two rows the spec got wrong

The README's S1 expects `receive` first for `recieve`, and S3 expects `brown` first for `brwon`.
Under Levenshtein as §2 defines it, both are two edits away (a transposition is two edits) while
`relieve` and `broon` are one edit away, so your output is right and the rows are wrong. Two
things follow:

- Ties within a distance are "alphabetical". Your sort uses byte order, so every capitalized
  dictionary word sorts before every lower-case one and `--max 8` cuts `brown` off the list. Is
  that what a user wants? Decide the tie-break (case-insensitive, then what?), state it in
  `--help`, and make `oracle.py` sort the same way so X2 still compares sets and the first-N
  order too.
- README §9 lists Damerau (a transposition counts as one edit) as a stretch goal, `--damerau`.
  Implement it as an option, with the oracle taking the same flag, and `check-index` and `bench`
  honouring it. With `--damerau`, S1 and S3 come out as the README wrote them. Think about what
  Damerau does to the triangle inequality the tree relies on, and say in a comment whether the
  tree's pruning is still exact under it (the oracle will tell you if you are wrong).

**Verify:** `./spell suggest brwon` lists `brown` within the first eight (by the tie-break you
chose); `./spell suggest --damerau recieve` → `receive` first; `./spell check-index --damerau
--seed 7` → `agree 500/500`; `test.sh` runs X2 both ways; `./test.sh` exits 0.

--- END FOLLOW-UP 5 ---

---

### FOLLOW-UP 6 — The test script is the product's proof

`test.sh` runs 20 oracle queries where X2 asks for 50, writes fixed paths under `/tmp`, and
encodes few of the §7.1 rows as exact-output checks. For a published tool the script is what a
stranger runs to decide whether to trust the binary.

- Every row in §7.1 (L1–E1) and every row you added in follow-ups 2–5 becomes a check with the
  exact expected bytes and exit status, named by its row id, so a failure says `S3 FAILED` and
  shows expected vs actual.
- X2 at 50 queries, seeded, both Levenshtein and Damerau. The script creates its own scratch
  directory (`mktemp -d`) and removes it; it never writes a fixed path.
- The README's §5 asks for an in-process agreement test (`bk_test.lu`: the tree against the brute
  force on a 500-word subset) so `wolf test .` alone catches a broken index without Python.
- `test.sh` must fail loudly when `wolf` is missing or the dictionary is absent, with exit 2 and
  a message, not a cascade of errors.

**Verify:** `./test.sh; echo $?` → `0`, its summary listing every row id and `agree 50/50` twice;
`wolf test .` shows the new agreement test; break something on purpose (one character in `lev.lu`),
show `test.sh` naming the row that catches it, then restore it.

--- END FOLLOW-UP 6 ---

---

### FOLLOW-UP 7 — Read it as a stranger

Read every `.lu` file top to bottom as someone who has never seen it. For each, answer in a
short note (`REVIEW.md`, yours, one section per file): what does this file own; what in it is no
longer called; what is done twice; what is a hand-rolled version of something `std` provides
(sorting with a key, searching, string building); which comments describe what the code did
rather than what it does. Then act on the note: delete dead code, replace hand-rolled algorithms
where `std` has them, make every error message the tool prints follow one shape
(`spell: <what>: <why>`), and give every public function a one-line doc comment that says what
it answers, not how.

Do not change behaviour: the proof is that `./test.sh` and `wolf test .` are green before and
after with no edits to the tests.

**Verify:** `REVIEW.md` written; `wolf fmt --check *.lu`; `wolf build` warning-free; `./test.sh`
exits 0; `wc -l *.lu` before and after in the note.

--- END FOLLOW-UP 7 ---

---

### FOLLOW-UP 8 — Ship it

Make the directory something wolffe-lang can publish as-is.

- `README.md` is currently the spec you were given. Replace it with a user's README: what
  `spell` does in two sentences, install (`wolf build main.lu -o spell`), usage with real
  examples and their real output (paste from the binary, do not type them), the suggestion rules
  (distance, tie-break, the `~` hint, `--damerau`), exit codes, `--dict`/`--ignore`, how to run
  the tests, how the oracle works and why it is there, and measured numbers from `bench` on this
  Mac with the date. Keep the original spec as `SPEC.md`.
- A `CHANGELOG.md` with one entry: the first release, what it does, what it does not do (no
  stemming, no grammar, the system word list is the whole truth).
- A `LICENSE` (ask which; default to the licence wolffe-lang's other tools use, and say so).
- Make sure nothing in the directory is scratch: no `.lu-cache`, no `/tmp` paths, no `bad.txt`,
  no leftover prompts. List the files that remain and what each is for, at the bottom of the
  README.
- Finally, the honesty line: at the top of the README, one sentence saying the tool was written
  by wollf-v7sf3 under this harness, with human review, and link the oracle test as the reason to
  trust it.

**Verify:** `ls` shows only the files the README lists; a fresh clone of the directory builds and
passes `./test.sh` with nothing else present; `./spell --help` matches the README's usage block
byte for byte; paste the README's examples section.

--- END FOLLOW-UP 8 ---
