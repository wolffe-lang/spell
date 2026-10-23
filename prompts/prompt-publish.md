# spell — the publish round (giveaway allowed)

The reviewer copied the working tree into an empty directory, built it, and checked it with an oracle of
their own, written from the definitions, not from `oracle.py`: plain Levenshtein and restricted
Damerau-Levenshtein, brute force over `/usr/share/dict/words`, sorted by distance, then case-insensitively,
capitalized first. On 40 queries (the spec's words and 30 random edits) `spell suggest` agrees in both modes,
in order, on 38. FINAL 1's transposition fix holds, `--help` equals the README's block byte for byte, every
example reproduces, and the whole dictionary checks clean. What is left blocks publishing. **Nothing from the
last rounds is committed yet**: eight files are modified and `prompts/` is untracked. One commit per item
below, in order, then stop and paste the last lines of each verify.

### PUBLISH 1 — all-caps words

`dict.lu`'s header promises "all uppercase form matching a dictionary word (`PARIS` → `Paris`)", and
RELEASE 1 asked for `./spell suggest PARIS` to treat it as known. It does not:

```
$ echo "PARIS is lovely" | ./spell -
1:1: PARIS  → (no suggestions)
$ ./spell suggest BRWON
BRWON  → (no suggestions)
```

`is_known_uppercase` lowers the whole word and looks up `paris`, but the dictionary spells the name `Paris`.
An all-caps token is known when any dictionary word equals it case-insensitively, whatever the word's own
case. An all-caps token that is not known gets the suggestions its lower-case form gets. Say in `--help` in
which case they are printed, and pick the one a reader expects. Rows: `suggest PARIS` → `PARIS: known`, exit 0;
`PARIS is lovely` on stdin → nothing, exit 0; `suggest BRWON` → the same list as `suggest brwon` in the case
you chose, exit 1.

### PUBLISH 2 — options say what they do

- `./spell --damerau FILE` exits 2 with `unknown option: --damerau`, yet `spell suggest --damerau` works and
  `--help` lists `--damerau` only on `bench`. Either the file mode takes `--damerau` too, or it does not and
  `--help` says so. In both cases the `suggest` usage line lists `[--damerau]`.
- `./spell suggest --dict /dev/null brwon` checks `--dict` and `/dev/null` as words
  (`--dict  → addict, edict, indict`). An argument that starts with `-` and is not an option `suggest`
  takes is a usage error: the usage block, exit 2, as RELEASE 2 asked for the file mode.

### PUBLISH 3 — rows that test what they name

`row()` runs `output=$($cmd 2>&1)`. An unquoted string is split on spaces and never interpreted, so:

- `row "stdin" "printf '' | $SPELL -" 0 ""` runs `printf` with the arguments `''`, `|`, `./spell` and `-`.
  It prints `''`, exits 0 and passes without spell ever running.
- `row "T1" "$SPELL suggest 'don't" 1 "don"` checks the word `'don't`, quote included, and `don` matches
  anything. It does not test tokenization.
- An empty pattern is documented as "no output", but nothing checks that the output is empty, so `D1`,
  `empty`, `dogs` and `stdin` check only the exit status.
- Every other row greps for a fragment, while RELEASE 4 asked for exact expected bytes.

Run each row's command through `bash -c "$cmd"`. Compare the whole output with the exact expected bytes, and
treat an empty expectation as "the output is empty". Make T1 a tokenization row in file mode, from SPEC §7.1,
with its exact expected lines. Plant: make the stdin path print one stray line, show the `stdin` row red, then
green. Update the row count everywhere it is stated.

### PUBLISH 4 — the licence is the official text

`LICENSE` is not the Apache License 2.0 word for word. §1's "Contribution" reads "submitted to the Licensor"
for "submitted to Licensor", and the APPENDIX is gone. A licence is never typed from memory:

```
curl -fsSL https://www.apache.org/licenses/LICENSE-2.0.txt -o LICENSE
shasum -a 256 LICENSE   # cfc7749b96f63bd31c3c42b5c471bf756814053e847c10f3eb003417bc523d30
```

### PUBLISH 5 — the README, the rest of the way

- The `Files` list omits the five test files (`agree_test.lu`, `dict_test.lu`, `lev_test.lu`,
  `tokens_test.lu`, `trie_test.lu`). It lists exactly `git ls-files`, one line each.
- The `spell FILE` example does not show its file. Show it: `printf 'The quick brwon fox\n' > t.txt` and then
  `spell t.txt`, both pasted.
- "How the index works" says the trie is "12x faster (3ms vs 38ms)", while `bench` today says a 2 ms median.
  Label the BK-tree numbers as measured at 0.1.0, and take today's numbers from `bench`.
- The PUBLISH 1–3 behaviour goes into the suggestion rules, the options and the CHANGELOG.

### PUBLISH 6 — commit, and prove it from a clone

Commit each item. `prompts/` holds `prompt.md`, `prompt-followup.md`, `prompt-v0.2.0.md`,
`prompt-release.md`, `prompt-final.md`, `prompt-final4.md` and this file. Then `git status --short` must be
empty after a full `./test.sh`, and `git clone . /tmp/spell-fresh && cd /tmp/spell-fresh && wolf build main.lu
-o spell && ./test.sh` must be green.

**Verify:** `wolf build` exit 0; `wolf fmt --check *.lu`; `wolf test .` and `./test.sh` green with the new
rows; the plant red then green; the clone run above; `shasum -a 256 LICENSE` as shown; `./spell --help` diffed
against the README's block, empty.
