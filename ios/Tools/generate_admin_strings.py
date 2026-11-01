#!/usr/bin/env python3
"""Writes ios/BanhAdmin/Localizable.xcstrings from the copy tables of the UI specification.

The tables (docs/design/admin-orders/08 and 09) are the single source of the Vietnamese text. Only keys
that the Swift sources use (`LocalizedStringResource("A_...")`) are written. `{name}` placeholders
become `%@`; `[vX.Y | date]` version tags are dropped.

    python3 ios/Tools/generate_admin_strings.py
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ROW = re.compile(r"^\| `(A_[A-Z0-9_]+)` \| (.+) \|$")
TAG = re.compile(r"\s*\[v\d+\.\d+ \\?\| [0-9-]+\]")
PLACEHOLDER = re.compile(r"\{[a-z]+\}")


def table_text():
    texts = {}
    for path in sorted(glob.glob(os.path.join(ROOT, "docs/design/admin-orders/0[89]-*.md"))):
        for line in open(path, encoding="utf-8"):
            match = ROW.match(line.rstrip("\n"))
            if match:
                texts[match.group(1)] = PLACEHOLDER.sub("%@", TAG.sub("", match.group(2))).strip()
    return texts


def used_keys():
    keys = set()
    for path in glob.glob(os.path.join(ROOT, "ios/BanhAdmin/**/*.swift"), recursive=True):
        keys.update(re.findall(r'"(A_[A-Z0-9_]+)"', open(path, encoding="utf-8").read()))
    return keys


def main():
    texts = table_text()
    keys = sorted(used_keys())
    missing = [key for key in keys if key not in texts]
    if missing:
        sys.exit("keys without text in docs/design/admin-orders/08 or 09: " + ", ".join(missing))
    strings = {
        key: {"localizations": {"vi": {"stringUnit": {"state": "translated", "value": texts[key]}}}} for key in keys
    }
    out = {"sourceLanguage": "vi", "strings": strings, "version": "1.0"}
    target = os.path.join(ROOT, "ios/BanhAdmin/Localizable.xcstrings")
    with open(target, "w", encoding="utf-8") as handle:
        json.dump(out, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
    print(f"wrote {len(keys)} strings to {target}")


main()
