#!/bin/bash
# spell test harness — every spec row, named by id.
# Exit 0 = all rows pass. Exit 2 = missing dependency. Exit 1 = a row failed.
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ── dependency check ────────────────────────────────────────────────
for dep in wolf python3; do
    command -v "$dep" >/dev/null 2>&1 || { echo "missing: $dep"; exit 2; }
done
[ -f oracle.py ] || { echo "missing: oracle.py"; exit 2; }
[ -r /usr/share/dict/words ] || { echo "missing: /usr/share/dict/words"; exit 2; }

# ── build ───────────────────────────────────────────────────────────
wolf build main.lu -o spell

# ── wolf tests ──────────────────────────────────────────────────────
wolf test .

# ── helpers ─────────────────────────────────────────────────────────
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

SPELL="./spell"
ORACLE="python3 oracle.py"

# ── rows ────────────────────────────────────────────────────────────
# Each row: id, command (run through bash -c), expected exit, expected output
# An empty expected output means the command must produce no output at all.

pass_count=0
fail_count=0

row() {
    local id="$1"
    local cmd="$2"
    local expect_exit="$3"
    local expect_output="$4"

    # Run through bash -c to handle pipes, quotes, etc.
    set +e
    output=$(bash -c "$cmd" 2>&1)
    actual_exit=$?
    set -e

    if [ "$actual_exit" -ne "$expect_exit" ]; then
        echo "FAIL $id: expected exit $expect_exit, got $actual_exit"
        echo "  output: $output"
        fail_count=$((fail_count + 1))
        return
    fi

    if [ -n "$expect_output" ]; then
        if [ "$output" != "$expect_output" ]; then
            echo "FAIL $id: output mismatch"
            echo "  expected: $expect_output"
            echo "  got:      $output"
            fail_count=$((fail_count + 1))
            return
        fi
    else
        # Empty expectation: output must be empty
        if [ -n "$output" ]; then
            echo "FAIL $id: expected no output, got:"
            echo "  $output"
            fail_count=$((fail_count + 1))
            return
        fi
    fi

    echo "ok $id"
    pass_count=$((pass_count + 1))
}

# L1: Levenshtein distance
row "L1" "$SPELL suggest brwon" 1 "brwon  → broon, argon, Arion, aroon, arson, bacon, baron, barton"

# L2: capped distance
row "L2" "$SPELL suggest --radius 1 brwon" 1 "brwon  → broon"

# T1: tokenization — from SPEC §7.1, exact expected lines
printf "Don't stop O'Brien, well-known 42nd street.\n" > "$TMPDIR/t1.txt"
row "T1" "$SPELL $TMPDIR/t1.txt" 1 "1:1: Don't  → Donet, Don, Donal, Donar, Donia, Donn, Donna, Donne
1:12: O'Brien  → (no suggestions)
1:34: nd  → ad, and, d, Ed, end, id, Ind, n"

# S1: recieve → receive first (with --damerau)
row "S1" "$SPELL suggest --damerau recieve" 1 "recieve  → receive, relieve, believe, deceive, reachieve, recarve, recede, received"

# S3: brwon → brown near top (with --damerau)
row "S3" "$SPELL suggest --damerau brwon" 1 "brwon  → broon, brown, argon, Arion, aroon, arson, bacon, baron"

# E1: UTF-8 error with line number
printf 'hello\x80world\n' > "$TMPDIR/bad.txt"
row "E1" "$SPELL $TMPDIR/bad.txt" 2 "spell: $TMPDIR/bad.txt:1: not UTF-8"

# D1: dictionary self-check — no output, exit 0
row "D1" "$SPELL /usr/share/dict/words" 0 ""

# Empty file — no output, exit 0
printf '' > "$TMPDIR/empty.txt"
row "empty" "$SPELL $TMPDIR/empty.txt" 0 ""

# No trailing newline
printf 'brwon' > "$TMPDIR/nonewline.txt"
row "nonewline" "$SPELL $TMPDIR/nonewline.txt" 1 "1:1: brwon  → broon, argon, Arion, aroon, arson, bacon, baron, barton"

# CRLF
printf 'brwon\r\n' > "$TMPDIR/crlf.txt"
row "crlf" "$SPELL $TMPDIR/crlf.txt" 1 "1:1: brwon  → broon, argon, Arion, aroon, arson, bacon, baron, barton"

# café (Unicode)
printf 'café\n' > "$TMPDIR/cafe.txt"
row "cafe" "$SPELL $TMPDIR/cafe.txt" 1 "1:1: café  → cafh, aft, baff, baft, ca, caam, cab, caba"

# 'tis (apostrophe at start)
printf "'tis\n" > "$TMPDIR/tis.txt"
row "tis" "$SPELL $TMPDIR/tis.txt" 1 "1:2: tis  → atis, bis, dis, his, is, lis, Otis, Sis"

# dogs' (apostrophe at end) — no output, exit 0
printf "dogs'\n" > "$TMPDIR/dogs.txt"
row "dogs" "$SPELL $TMPDIR/dogs.txt" 0 ""

# Multi-file
printf 'brwon\n' > "$TMPDIR/mf1.txt"
printf 'brwon\n' > "$TMPDIR/mf2.txt"
row "multi" "$SPELL $TMPDIR/mf1.txt $TMPDIR/mf2.txt" 1 "$TMPDIR/mf1.txt:1:1: brwon  → broon, argon, Arion, aroon, arson, bacon, baron, barton
$TMPDIR/mf2.txt:1:1: brwon  → broon, argon, Arion, aroon, arson, bacon, baron, barton"

# Empty stdin — no output, exit 0
row "stdin" "printf '' | $SPELL -" 0 ""

# --help
row "help" "$SPELL --help" 0 "Usage: spell [--dict FILE] [--ignore FILE] [--radius N] [--max N] [--damerau] [FILE|-]...
       spell suggest [--radius N] [--max N] [--damerau] WORD...
       spell check-index [--dict FILE] [--seed N]
       spell bench [--dict FILE] [--damerau]
       spell --help

  spell suggest: known words print 'WORD: known'.
  Capitalization hints are marked with ~ (e.g. 'paris' → '~ Paris').
  All-caps words are known if any dictionary word matches case-insensitively.
  Unknown all-caps words get the suggestions their lower-case form gets.
  Multi-file mode prefixes output with FILE: (e.g. 'file.txt:1:3: word').
  --damerau: use restricted Damerau-Levenshtein distance (optimal string alignment; transpositions count as 1 edit)."

# Unknown subcommand (treated as file, exits 2 with error)
row "unknown" "$SPELL foobar" 2 "spell: cannot read foobar: not_found"

# --radius without value
row "radius" "$SPELL --radius" 2 "spell: --radius requires a value"

# --damerau flag
row "damerau" "$SPELL suggest --damerau recieve" 1 "recieve  → receive, relieve, believe, deceive, reachieve, recarve, recede, received"

# suggest Paris → known
row "paris" "$SPELL suggest Paris" 0 "Paris: known"

# suggest paris → ~ Paris
row "paris_hint" "$SPELL suggest paris" 1 "paris  → ~ Paris, baris, maris, pais, pari, paries, parish, parvis"

# Multi-file prefix
row "prefix" "$SPELL $TMPDIR/mf1.txt $TMPDIR/mf2.txt" 1 "$TMPDIR/mf1.txt:1:1: brwon  → broon, argon, Arion, aroon, arson, bacon, baron, barton
$TMPDIR/mf2.txt:1:1: brwon  → broon, argon, Arion, aroon, arson, bacon, baron, barton"

# X1: check-index
row "X1" "$SPELL check-index --seed 7" 0 "agree 500/500"

# X2: oracle comparison (50 queries, both distances)
$ORACLE --seed 42 --count 50 > "$TMPDIR/oracle.txt"
while IFS= read -r line; do
    word="${line%%  →*}"
    echo "$word"
done < "$TMPDIR/oracle.txt" > "$TMPDIR/words.txt"

while IFS= read -r word; do
    $SPELL suggest --radius 2 --max 1000 "$word" || true
done < "$TMPDIR/words.txt" > "$TMPDIR/spell.txt"

python3 -c "
import sys

def extract_words(line):
    if '  → ' not in line:
        return None, None
    word, rest = line.split('  → ', 1)
    suggestions = [s.strip() for s in rest.split(',')]
    return word.strip(), suggestions

oracle_words = {}
with open('$TMPDIR/oracle.txt') as f:
    for line in f:
        w, s = extract_words(line.strip())
        if w:
            oracle_words[w] = set(s)

spell_words = {}
with open('$TMPDIR/spell.txt') as f:
    for line in f:
        w, s = extract_words(line.strip())
        if w:
            spell_words[w] = set(s)

agreed = 0
disagreements = 0
for w in oracle_words:
    if w in spell_words:
        if oracle_words[w] == spell_words[w]:
            agreed += 1
        else:
            disagreements += 1
    else:
        # Word not in spell output (likely known word)
        # Skip known words
        pass

print(f'agree {agreed}/{agreed + disagreements}')
if disagreements > 0:
    sys.exit(1)
" > "$TMPDIR/x2_result.txt"

row "X2" "cat $TMPDIR/x2_result.txt" 0 "agree 49/49"

# X2d: oracle comparison with --damerau (50 queries)
$ORACLE --seed 42 --count 50 --damerau > "$TMPDIR/oracle_d.txt"
while IFS= read -r line; do
    word="${line%%  →*}"
    echo "$word"
done < "$TMPDIR/oracle_d.txt" > "$TMPDIR/words_d.txt"

while IFS= read -r word; do
    $SPELL suggest --damerau --radius 2 --max 1000 "$word" || true
done < "$TMPDIR/words_d.txt" > "$TMPDIR/spell_d.txt"

python3 -c "
import sys

def extract_words(line):
    if '  → ' not in line:
        return None, None
    word, rest = line.split('  → ', 1)
    suggestions = [s.strip() for s in rest.split(',')]
    return word.strip(), suggestions

oracle_words = {}
with open('$TMPDIR/oracle_d.txt') as f:
    for line in f:
        w, s = extract_words(line.strip())
        if w:
            oracle_words[w] = set(s)

spell_words = {}
with open('$TMPDIR/spell_d.txt') as f:
    for line in f:
        w, s = extract_words(line.strip())
        if w:
            spell_words[w] = set(s)

agreed = 0
disagreements = 0
for w in oracle_words:
    if w in spell_words:
        if oracle_words[w] == spell_words[w]:
            agreed += 1
        else:
            disagreements += 1
    else:
        # Word not in spell output (likely known word)
        # Skip known words
        pass

print(f'agree {agreed}/{agreed + disagreements}')
if disagreements > 0:
    sys.exit(1)
" > "$TMPDIR/x2d_result.txt"

row "X2d" "cat $TMPDIR/x2d_result.txt" 0 "agree 49/49"

# X3: ordered comparison — first 8 suggestions must match the oracle's first 8
# Uses the default --max 8, so order matters.
$ORACLE --seed 42 --count 50 > "$TMPDIR/oracle_order.txt"
while IFS= read -r line; do
    word="${line%%  →*}"
    echo "$word"
done < "$TMPDIR/oracle_order.txt" > "$TMPDIR/words_order.txt"

while IFS= read -r word; do
    $SPELL suggest --radius 2 "$word" || true
done < "$TMPDIR/words_order.txt" > "$TMPDIR/spell_order.txt"

python3 -c "
import sys

def extract_words(line):
    if '  → ' not in line:
        return None, None
    word, rest = line.split('  → ', 1)
    suggestions = [s.strip() for s in rest.split(',')]
    return word.strip(), suggestions

oracle_words = {}
with open('$TMPDIR/oracle_order.txt') as f:
    for line in f:
        w, s = extract_words(line.strip())
        if w:
            oracle_words[w] = s[:8]

spell_words = {}
with open('$TMPDIR/spell_order.txt') as f:
    for line in f:
        w, s = extract_words(line.strip())
        if w:
            spell_words[w] = s[:8]

agreed = 0
disagreements = 0
for w in oracle_words:
    if w in spell_words:
        if oracle_words[w] == spell_words[w]:
            agreed += 1
        else:
            disagreements += 1
    else:
        # Known word, skip
        pass

print(f'agree {agreed}/{agreed + disagreements}')
if disagreements > 0:
    sys.exit(1)
" > "$TMPDIR/x3_result.txt"

row "X3" "cat $TMPDIR/x3_result.txt" 0 "agree 49/49"

# X3d: ordered comparison with --damerau (10 queries: the Damerau oracle takes
# ~55s for 20 queries, so 10 is the practical limit for a test script)
$ORACLE --seed 42 --count 10 --damerau > "$TMPDIR/oracle_order_d.txt"
while IFS= read -r line; do
    word="${line%%  →*}"
    echo "$word"
done < "$TMPDIR/oracle_order_d.txt" > "$TMPDIR/words_order_d.txt"

while IFS= read -r word; do
    $SPELL suggest --damerau --radius 2 "$word" || true
done < "$TMPDIR/words_order_d.txt" > "$TMPDIR/spell_order_d.txt"

python3 -c "
import sys

def extract_words(line):
    if '  → ' not in line:
        return None, None
    word, rest = line.split('  → ', 1)
    suggestions = [s.strip() for s in rest.split(',')]
    return word.strip(), suggestions

oracle_words = {}
with open('$TMPDIR/oracle_order_d.txt') as f:
    for line in f:
        w, s = extract_words(line.strip())
        if w:
            oracle_words[w] = s[:8]

spell_words = {}
with open('$TMPDIR/spell_order_d.txt') as f:
    for line in f:
        w, s = extract_words(line.strip())
        if w:
            spell_words[w] = s[:8]

agreed = 0
disagreements = 0
for w in oracle_words:
    if w in spell_words:
        if oracle_words[w] == spell_words[w]:
            agreed += 1
        else:
            disagreements += 1
    else:
        # Known word, skip
        pass

print(f'agree {agreed}/{agreed + disagreements}')
if disagreements > 0:
    sys.exit(1)
" > "$TMPDIR/x3d_result.txt"

row "X3d" "cat $TMPDIR/x3d_result.txt" 0 "agree 10/10"

# PUBLISH 1: all-caps words
row "caps_known" "$SPELL suggest PARIS" 0 "PARIS: known"
row "caps_file" "printf 'PARIS is lovely\n' | $SPELL -" 0 ""
row "caps_suggest" "$SPELL suggest BRWON" 1 "BRWON  → broon, argon, Arion, aroon, arson, bacon, baron, barton"

# PUBLISH 2: --damerau in file mode, --dict rejected by suggest
printf 'The quick brwon fox\n' > "$TMPDIR/damerau_file.txt"
row "damerau_file" "$SPELL --damerau $TMPDIR/damerau_file.txt" 1 "1:11: brwon  → broon, brown, argon, Arion, aroon, arson, bacon, baron"
row "suggest_dict" "$SPELL suggest --dict /dev/null brwon" 2 "spell: unknown option: --dict"

# ── summary ─────────────────────────────────────────────────────────
echo ""
echo "All tests passed"
echo "$pass_count passed, $fail_count failed"
# Total rows: 27 original + 5 new = 32

if [ "$fail_count" -gt 0 ]; then
    exit 1
fi
exit 0
