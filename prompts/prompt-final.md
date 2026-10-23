# spell — the final round before publishing (giveaway allowed)

The reviewer built a fresh clone of this repository and checked every claim. Four things stand between it
and `wolffe-lang/spell`. Do them in order, one commit each, then stop and paste the last lines.

### FINAL 1 — A transposition costs one edit, and the oracle had the same bug

`lev.lu`, `damerau_distance_capped`:

    let trans = dp[i - 2][j - 2]

and `oracle.py`, `damerau_levenshtein`:

    dp[i][j] = min(dp[i][j], dp[i - 2][j - 2])

Both make a transposition free. The cost is `dp[i - 2][j - 2] + 1` in both. The symptom: `spell suggest
--damerau --radius 2 recieve` lists `perceive` (three edits away), and `spell suggest --damerau brwon`
prints `brown, blown, broon, …` where the right answer is `broon, brown, argon, Arion, aroon, arson, bacon,
baron`. X2d agreed because the oracle shared the bug: two copies of one mistake are not a check.

Add unit rows whose expected values come from the definition, not from either implementation:
`ab`/`ba` 1, `abc`/`acb` 1, `recieve`/`receive` 1, `brwon`/`brown` 1, `brwon`/`blown` 2,
`recieve`/`perceive` 3, and `ca`/`abc` 3. That last one is 3 because this is the *restricted* form (optimal
string alignment: no edit inside a transposed pair); full Damerau-Levenshtein would say 2. Say "restricted
Damerau-Levenshtein (optimal string alignment)" wherever the README, `--help` and the CHANGELOG say
"Damerau-Levenshtein".

### FINAL 2 — The oracle comparison checks order, not just membership

X2 and X2d run `spell suggest --max 1000` and compare sets, so a wrong order or a wrong top 8 passes. Keep
the set rows and add two that compare the ordered list at the default `--max 8` against the oracle's first
8 (it already sorts by distance, then case-insensitively). Plant: put FINAL 1's bug back in `lev.lu` only
and show X2d red, then green.

### FINAL 3 — Every example is pasted from the binary

The banner says every claim below it is pasted from the binary. Two are not: the `spell FILE` example and
the `spell suggest brwon` example show `brown, broon, …`, which the binary does not print. Regenerate every
example block by running its command and pasting the output. Add the `--help` text as its own block,
byte-identical to `./spell --help`. Say that `--damerau` searches by brute force (the trie walks Levenshtein
only), and remove `check-index --damerau`: it compares brute force with brute force and so checks nothing.
Note the removal in the CHANGELOG. `spell suggest` should take `--dict` and `--ignore` as the file mode does;
if you would rather not, the README must say it does not.

### FINAL 4 — Licence and tree

The licence is Apache-2.0 (the maintainer's ruling for both wollf-built tools); keep `LICENSE`. Do not
write that it is "the licence wolffe-lang's tools use": it is not. The README line is "Licensed under the
Apache License 2.0 (`LICENSE`)." `prompts/` is part of the repository (the banner points at it): this file
goes in it too. Update the test counts the README states.

**Verify:** `wolf build main.lu -o spell` exit 0; `wolf fmt --check *.lu`; `wolf test .` and `./test.sh`
green with the new rows; the X2d plant red then green; a fresh clone into an empty directory builds and
passes; every README example equals what the binary prints; `ls -A` matches the README's file list.
