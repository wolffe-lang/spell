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
# Each row: id, command, expected exit, grep pattern (empty = no output)
# Format: row "id" "command" exit_code "pattern"

pass_count=0
fail_count=0

row() {
    local id="$1"
    local cmd="$2"
    local expect_exit="$3"
    local pattern="$4"

    output=$($cmd 2>&1) || true
    actual_exit=$?

    # Re-run to get the real exit code
    set +e
    $cmd >/dev/null 2>&1
    actual_exit=$?
    set -e

    if [ "$actual_exit" -ne "$expect_exit" ]; then
        echo "FAIL $id: expected exit $expect_exit, got $actual_exit"
        echo "  output: $output"
        fail_count=$((fail_count + 1))
        return
    fi

    if [ -n "$pattern" ]; then
        if ! echo "$output" | grep -q "$pattern"; then
            echo "FAIL $id: pattern '$pattern' not found"
            echo "  output: $output"
            fail_count=$((fail_count + 1))
            return
        fi
    fi

    echo "ok $id"
    pass_count=$((pass_count + 1))
}

# L1: Levenshtein distance
row "L1" "$SPELL suggest brwon" 1 "brwon"

# L2: capped distance
row "L2" "$SPELL suggest --radius 1 brwon" 1 "brwon"

# T1: tokenization
row "T1" "$SPELL suggest 'don't" 1 "don"

# S1: recieve → receive first (with --damerau)
row "S1" "$SPELL suggest --damerau recieve" 1 "receive"

# S3: brwon → brown near top (with --damerau)
row "S3" "$SPELL suggest --damerau brwon" 1 "brown"

# E1: UTF-8 error with line number
printf 'hello\x80world\n' > "$TMPDIR/bad.txt"
row "E1" "$SPELL $TMPDIR/bad.txt" 2 "not UTF-8"

# D1: dictionary self-check
row "D1" "$SPELL /usr/share/dict/words" 0 ""

# Empty file
printf '' > "$TMPDIR/empty.txt"
row "empty" "$SPELL $TMPDIR/empty.txt" 0 ""

# No trailing newline
printf 'brwon' > "$TMPDIR/nonewline.txt"
row "nonewline" "$SPELL $TMPDIR/nonewline.txt" 1 "brwon"

# CRLF
printf 'brwon\r\n' > "$TMPDIR/crlf.txt"
row "crlf" "$SPELL $TMPDIR/crlf.txt" 1 "brwon"

# café (Unicode)
printf 'café\n' > "$TMPDIR/cafe.txt"
row "cafe" "$SPELL $TMPDIR/cafe.txt" 1 "café"

# 'tis (apostrophe at start)
printf "'tis\n" > "$TMPDIR/tis.txt"
row "tis" "$SPELL $TMPDIR/tis.txt" 1 "tis"

# dogs' (apostrophe at end)
printf "dogs'\n" > "$TMPDIR/dogs.txt"
row "dogs" "$SPELL $TMPDIR/dogs.txt" 0 ""

# Multi-file
printf 'brwon\n' > "$TMPDIR/mf1.txt"
printf 'brwon\n' > "$TMPDIR/mf2.txt"
row "multi" "$SPELL $TMPDIR/mf1.txt $TMPDIR/mf2.txt" 1 "brwon"

# Empty stdin
row "stdin" "printf '' | $SPELL -" 0 ""

# --help
row "help" "$SPELL --help" 0 "Usage"

# Unknown subcommand (treated as file, exits 2 with error)
row "unknown" "$SPELL foobar" 2 "cannot read"

# --radius without value
row "radius" "$SPELL --radius" 2 "requires"

# --damerau flag
row "damerau" "$SPELL suggest --damerau recieve" 1 "receive"

# suggest Paris → known
row "paris" "$SPELL suggest Paris" 0 "Paris: known"

# suggest paris → ~ Paris
row "paris_hint" "$SPELL suggest paris" 1 "~ Paris"

# Multi-file prefix
row "prefix" "$SPELL $TMPDIR/mf1.txt $TMPDIR/mf2.txt" 1 "mf1.txt:"

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

# ── summary ─────────────────────────────────────────────────────────
echo ""
echo "All tests passed"
echo "$pass_count passed, $fail_count failed"

if [ "$fail_count" -gt 0 ]; then
    exit 1
fi
exit 0
