# spell — the release round (to a public repository under wolffe-lang, "built by wollf")

Paste one at a time. The reviewer re-ran v0.2.0 in a clean copy: 2 ms median, 15× over brute force,
500/500 with the oracle, 0.1 s startup. It is a tool now. This round makes it one a stranger can trust and
install. Same rules as before: one directory, one module; no `Map` beyond a few thousand entries; stop at
the end of each release step and paste the last lines and statuses; every claim in the README is pasted
output, never typed.

---

### RELEASE 1 — The dictionary knows all of itself

The reviewer ran `./spell /usr/share/dict/words` — the dictionary as the text to check — and spell flagged
46 of its own 235,976 words as unknown: `ambro`, `sially`, `arbalestrie`, `barrin`, `Brahmanis` among them.
Before you look at the code, answer in `dict.lu`'s header: what does a binary search require of its list, is
the file on disk in that order (`LC_ALL=C sort -c /usr/share/dict/words` tells you), and what did PHASE D
remove from `load_dict` to get the build time down? Then look at what else you already have: there are two
indexes of the same words in this program, and one of them is exact for every word and answers a lookup in
the length of the word. What should `is_known` be built on? While there, `is_known_uppercase` lowers every
one of 236k words for each all-caps token; the same thought applies.

Add the whole-dictionary self-check to `test.sh` as a permanent row (`D1`: every dictionary word is known,
exit 0, nothing printed) and to `wolf test .` on a 2,000-word slice.

**Verify:** `./spell /usr/share/dict/words; echo $?` → nothing, `0`; `./spell suggest PARIS` treats it as
known in well under 10 ms; `./spell bench` build still under 100 ms; `./test.sh` lists `ok D1`.

--- END RELEASE 1 ---

---

### RELEASE 2 — What a user sees at the edges

- `spell suggest Paris` prints nothing. A user cannot tell silence from a crash. Decide what `suggest` says
  about a known word (one line, say `Paris: known`), put it in `--help`, and make it a row.
- `spell -q` says `cannot open -q: not_found`. An unknown option is a usage error: the usage block, exit 2.
  Same for `--radius` without a number or with `3`.
- Several files on one command line: does the output name the file? (`FILE:LINE:COL` when more than one
  file, `LINE:COL` for one or stdin: decide, document in `--help`, and make it a row.)
- Keep every edge row from FOLLOW-UP 3 that already passes (empty file, no trailing newline, CRLF, E1's
  line) in `test.sh` by id if it is not there yet.

**Verify:** each as a row with its exact bytes and exit status; `./test.sh` exits 0.

--- END RELEASE 2 ---

---

### RELEASE 3 — Ordering, and `--damerau` (FOLLOW-UP 5, unchanged)

The spec's S1 (`recieve → receive` first) and S3 (`brwon → brown` near the top) assume a transposition is one
edit, and today's tie-break sorts every capitalized word before every lower-case one so `brown` falls off an
8-item list. Do FOLLOW-UP 5 as written: the case-insensitive tie-break stated in `--help` and mirrored in
`oracle.py`, then `--damerau` for the walk and the oracle. In the trie walk a transposition needs the
grandparent's row beside the parent's: say in the header how the row-per-depth storage carries it, then
measure the median again (it will cost something; say how much).

**Verify:** `./spell suggest brwon` lists `brown` within the first eight; `./spell suggest --damerau recieve`
→ `receive` first; `./spell check-index --damerau --seed 7` → `agree 500/500`; `bench` with and without the
flag; `./test.sh` runs X2 both ways.

--- END RELEASE 3 ---

---

### RELEASE 4 — The test script is the product's proof (FOLLOW-UP 6, plus)

- Every §7.1 row of the spec (L1–E1) and every row added since (D1, the edges, the hint, `--damerau`) as a
  check with exact expected bytes and exit status, named by id, built from two lists at the top of the
  script; a missing directory, oracle, `wolf` or dictionary is a loud failure with exit 2.
- X2 at 50 queries, both distances; `mktemp -d` for every scratch file; nothing written to a fixed path.
- An in-process agreement test in `wolf test .` (trie against brute force on a 2,000-word slice and 50
  edited queries) so a broken index fails without Python.
- Break one character in `trie.lu`'s prune and show which rows catch it, then restore it.

**Verify:** `./test.sh; echo $?` → `0` with one `ok <row>` line per cell and the count; the deliberate break
shows `FAIL`; a run from a copy without `oracle.py` exits 2 with a message.

--- END RELEASE 4 ---

---

### RELEASE 5 — Read it as a stranger (FOLLOW-UP 7, plus the walk's last allocation)

`REVIEW.md`, one section per file: what it owns, what is dead, what is done twice, what `std` already
provides, which comments describe the past. Then act without changing behaviour (the proof: `./test.sh` and
`wolf test .` green before and after with no test edits): dead imports and functions out (the `sort` import,
anything the BK-tree left), one message shape for every error (`spell: <what>: <why>`), one-line doc comments
on public functions. One performance item is allowed because it is also a clarity item: the walk pushes a
fresh `List[int]` row onto its stack per visited node. Your PHASE A design had one row per depth in storage
made once per query; make the code match the design and measure the per-visit cost before and after.

**Verify:** `REVIEW.md`; `wolf fmt --check *.lu`; `wolf build` warning-free; `./test.sh` exits 0;
`wc -l *.lu` before and after; `bench` before and after.

--- END RELEASE 5 ---

---

### RELEASE 6 — Ship it

The directory becomes the repository `wolffe-lang/spell`. Make it so that a stranger who clones it and runs
two commands trusts it.

- **`README.md`** (the spec you were given moves to `SPEC.md` unchanged): at the very top, before the title,
  this banner, verbatim:

  > **Built by wollf.** This program was written by [wollf-v7sf3](https://huggingface.co/wolffe-lang/wollf-v7sf3),
  > a 27B model trained to write wolf, driven through opencode by the prompts in `prompts/`, with a human
  > reviewer judging each phase and writing the next. Every claim below is pasted from the binary; the test
  > script is the reason to trust it.

  Then: what `spell` does in two sentences; install (`wolf build main.lu -o spell`; the wolf version it was
  built with, from `wolf --version`); usage with real pasted output for `spell FILE`, `spell suggest`,
  `check-index` and `bench`; the suggestion rules (distance, the tie-break, the `~` hint, `--damerau`); exit
  codes; `--dict`, `--ignore`; how the index works (the trie and the DP row, five sentences, and why the
  BK-tree was replaced, with both numbers); how to run the tests and what the oracle is; measured numbers
  with the date and machine; the file list with one line each; the licence line.
- **`prompts/`**: copy `prompt.md`, `prompt-followup.md`, `prompt-v0.2.0.md` and this file into it, unchanged
  (they are part of the story the banner tells).
- **`CHANGELOG.md`**: `0.2.0` — the trie index, the sorted-dictionary fix, Damerau, the edges; `0.1.0` — the
  first build (the BK-tree, the oracle). What it does not do (no stemming, no grammar, the system word list is
  the whole truth).
- **`LICENSE`**: Apache-2.0 (the licence wolffe-lang's tools use) with the wolf Training Data Permission
  notice copied from boreutils' `LICENSE` if the reviewer confirms; ask as R-1 and default to Apache-2.0 alone.
- **`.gitignore`**: the binary, `.lu-cache/`, `*.dSYM`, scratch files.
- A clean tree: no `spell` binary, no `bad.txt`, no `JUDGE.md` (the reviewer's; it moves out), nothing the
  README does not list.

**Verify:** `ls -A` matches the README's file list; a fresh copy of the directory into an empty folder builds
and passes `./test.sh` with nothing else present; `./spell --help` equals the README's usage block byte for
byte; paste the README's banner and examples section.

--- END RELEASE 6 ---
