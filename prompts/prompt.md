# spell — v3 (multi-phase, low give-away)

This build is delivered as **phases**, pasted one at a time. Do **only** the current
phase, make its **verification** pass, then stop and wait for the next. Keep earlier
phases working. One directory, one wolf module, one `main`.

---

### PHASE 0 — Setup & spec

First run `cp ../../README.md ./README.md && cp ../../../WOLF-NOTES.md ./WOLF-NOTES.md`,
then read both fully. Confirm `/usr/share/dict/words` exists and count its lines. Write
`main.lu` with README §4's dispatch (`--help` 0; unknown 2) and your file layout as a
comment.

**Verify:** `wolf build main.lu -o spell` warning-free; `./spell --help; echo $?` → `0`;
`wolf fmt --check *.lu`.

--- END PHASE 0 ---

---

### PHASE 1 — The distance (M1)

`lev.lu`: Levenshtein over code points, plain and capped with early exit; tests L1, L2.

**Verify:** `wolf test .` green on L1, L2.

--- END PHASE 1 ---

---

### PHASE 2 — Dictionary and tokens (M2; FR-7, FR-9)

`dict.lu` with the case rules; `tokens.lu` with T1's rules; `spell FILE` flagging
unknown words with `(no suggestions)`; E1.

**Verify:** T1, S4, E1; `printf 'brwon\n' | ./spell -` flags `1:1: brwon`.

--- END PHASE 2 ---

---

### PHASE 3 — Brute-force suggestions (M3; FR-1, FR-2, FR-3)

Suggestions by scanning the whole dictionary (slow, correct), nearest first then
alphabetical, `--radius`, `--max`, the capitalization hint; `suggest`. `oracle.py` and
`test.sh` with X2.

**Verify:** S1, S2, S3, S5; X2 agreeing.

--- END PHASE 3 ---

---

### PHASE 4 — The BK-tree (M4; FR-4, FR-5, FR-6)

`bk.lu` over an arena; `check-index` comparing the tree with the brute force on 500
edited dictionary words; `bench`; the tree replaces the scan in the user path only after
`check-index` agrees.

**Verify:** X1 `agree 500/500`; X2 still agreeing through the tree; B1's numbers.

--- END PHASE 4 ---

---

### PHASE 5 — Finish (M5; FR-8)

`--ignore`, `--dict`; every row in `test.sh`.

**Verify:** `./test.sh; echo $?` → `0`; `wolf test .` and `wolf fmt --check *.lu` clean.
Paste the last lines and statuses.

--- END PHASE 5 ---
