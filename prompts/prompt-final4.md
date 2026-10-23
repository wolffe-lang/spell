FINAL 4 — Licence and tree

The licence is Apache-2.0 (the maintainer's ruling for both wollf-built tools); keep `LICENSE`. Do not
write that it is "the licence wolffe-lang's tools use": it is not. The README line is "Licensed under the
Apache License 2.0 (`LICENSE`)." `prompts/` is part of the repository (the banner points at it): this file
goes in it too. Update the test counts the README states.

**Verify:** `wolf build main.lu -o spell` exit 0; `wolf fmt --check *.lu`; `wolf test .` and `./test.sh`
green with the new rows; the X2d plant red then green; a fresh clone into an empty directory builds and
passes; every README example equals what the binary prints; `ls -A` matches the README's file list.
