#!/usr/bin/env python3
"""Brute-force Levenshtein oracle for spell checker verification.

Generates random misspellings of dictionary words and computes the
complete set of suggestions at radius 2 by scanning the entire
dictionary. Output is one line per query: the misspelled word followed
by a comma-separated list of suggestions, sorted by distance then
alphabetically.

Usage: python3 oracle.py --dict /usr/share/dict/words --seed N --count N
"""

import argparse
import random
import sys


def levenshtein(a: str, b: str) -> int:
    """Compute the Levenshtein distance between two strings."""
    if len(a) < len(b):
        return levenshtein(b, a)
    if len(b) == 0:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a):
        curr = [i + 1]
        for j, cb in enumerate(b):
            if ca == cb:
                curr.append(prev[j])
            else:
                curr.append(1 + min(curr[j], prev[j + 1], prev[j]))
        prev = curr
    return prev[-1]


def damerau_levenshtein(a: str, b: str) -> int:
    """Compute the Damerau-Levenshtein distance (with transpositions)."""
    n = len(a)
    m = len(b)
    dp = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n + 1):
        dp[i][0] = i
    for j in range(m + 1):
        dp[0][j] = j
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            if a[i - 1] == b[j - 1]:
                dp[i][j] = dp[i - 1][j - 1]
            else:
                dp[i][j] = 1 + min(dp[i][j - 1], dp[i - 1][j], dp[i - 1][j - 1])
            # Transposition (restricted: cost is dp[i-2][j-2] + 1)
            if i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]:
                dp[i][j] = min(dp[i][j], dp[i - 2][j - 2] + 1)
    return dp[n][m]


def apply_random_edit(word: str, rng: random.Random) -> str:
    """Apply a random edit: substitution, deletion, insertion, or transposition."""
    edit_type = rng.randint(0, 3)
    n = len(word)
    if n == 0:
        return "a"

    if edit_type == 0:
        # Substitution
        pos = rng.randint(0, n - 1)
        new_char = chr(rng.randint(ord('a'), ord('z')))
        return word[:pos] + new_char + word[pos + 1:]
    elif edit_type == 1:
        # Deletion
        pos = rng.randint(0, n - 1)
        return word[:pos] + word[pos + 1:]
    elif edit_type == 2:
        # Insertion
        pos = rng.randint(0, n)
        new_char = chr(rng.randint(ord('a'), ord('z')))
        return word[:pos] + new_char + word[pos:]
    else:
        # Transposition
        if n < 2:
            return word
        pos = rng.randint(0, n - 2)
        return word[:pos] + word[pos + 1] + word[pos] + word[pos + 2:]


def suggest_brute(query: str, words: list[str], k: int, damerau: bool = False) -> list[tuple[int, str]]:
    """Find all dictionary words within edit distance k of the query."""
    candidates = []
    for word in words:
        if damerau:
            d = damerau_levenshtein(query, word)
        else:
            d = levenshtein(query, word)
        if d <= k:
            candidates.append((d, word))
    # Sort by distance, then case-insensitively
    candidates.sort(key=lambda x: (x[0], x[1].lower()))
    return candidates


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dict", default="/usr/share/dict/words")
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--count", type=int, default=50)
    parser.add_argument("--damerau", action="store_true")
    args = parser.parse_args()

    with open(args.dict) as f:
        words = [line.strip() for line in f if line.strip()]

    rng = random.Random(args.seed)
    results = []

    for _ in range(args.count):
        word = rng.choice(words)
        misspelled = apply_random_edit(word, rng)
        suggestions = suggest_brute(misspelled, words, 2, args.damerau)
        words_only = [w for _, w in suggestions]
        results.append(f"{misspelled}  → {', '.join(words_only)}")

    for line in results:
        print(line)


if __name__ == "__main__":
    main()
