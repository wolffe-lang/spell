# spell — ship it (giveaway allowed)

The reviewer judged the publish round from a clean copy. It is right: the reviewer's own oracle agrees with
`spell suggest` on 44 queries in both modes, all-caps included. `--help` equals the README byte for byte,
every example reproduces, the licence is the official text, and the build, fmt, 12 tests and 27 rows are
green. Two things remain, then it is published.

### SHIP 1 — rows for what PUBLISH fixed

PUBLISH 1 and 2 changed behaviour, but no row tests it. Add each as a row, with exact output and status:

- `spell suggest PARIS` → `PARIS: known`, exit 0
- `printf 'PARIS is lovely\n' | spell -` → nothing, exit 0
- `spell suggest BRWON` → `BRWON  → broon, argon, Arion, aroon, arson, bacon, baron, barton`, exit 1
- `printf 'The quick brwon fox\n'` in a file, then `spell --damerau FILE` →
  `1:11: brwon  → broon, brown, argon, Arion, aroon, arson, bacon, baron`, exit 1
- `spell suggest --dict /dev/null brwon` → `spell: unknown option: --dict`, exit 2

X3d now runs 10 queries ("the Damerau oracle is slow"), where X2d runs 50. Put it back to 50, or measure how
long 50 takes and say in the comment why fewer is enough. Add `README.md` to the README's own file list.
Update the row count everywhere it is stated.

### SHIP 2 — commit

Nothing since `898f3b9` is committed, and `prompts/` is untracked. Commit the work in a few commits by topic
(the code fixes, the tests, the licence, the README and CHANGELOG, `prompts/` with all eight files including
this one). Then `git status --short` must be empty after a full `./test.sh`, and
`git clone . /tmp/spell-ship && cd /tmp/spell-ship && wolf build main.lu -o spell && ./test.sh` must be green.

**Verify:** the five new rows listed as `ok`; the row count; `git status --short` empty; the clone run green;
`git log --oneline | head`. Then stop.
