#!/usr/bin/env python3
"""Measure a Markdown article against its length target.

Counts what a reader reads: Markdown syntax, link targets, HTML comments, and
front matter are stripped; review markers ([PRÜFEN: ...], [OFFEN: ...],
[ABBILDUNG n: ...]) are listed and excluded from the count, because they will
not be in the published text. Fenced code blocks are reported separately and
only counted when --include-code is given.

Usage:
    count_length.py ARTICLE.md [--unit words|chars] [--target N] [--limit N]
                    [--tolerance PCT] [--include-code]

--target N is the agreed length; the draft passes within +/- tolerance of it.
--limit N is a hard ceiling set by the medium; the draft fails above it, whatever
the tolerance says. Both may be given (target below the limit); --limit alone
uses the limit as target with the ceiling at the limit.

Exit status: 0 in tolerance (or no target given), 1 out of tolerance,
2 the file could not be read or an argument is invalid.
"""

import argparse
import re
import sys

# Matches exactly the marker forms SKILL.md step 5 prescribes: the keyword,
# an optional figure number, then a colon. The colon is required so that
# ordinary link text such as "[Open Source](...)" is never taken for a marker.
MARKER = re.compile(r"\[(PRÜFEN|OFFEN|ABBILDUNG(?:\s+\d+)?)\s*:[^\]]*\]")
# A fence opener: at least three backticks or tildes. The closer must use the
# same character and at least as many of them (CommonMark), so a ``` line
# inside a ~~~ block does not close it.
FENCE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")
HEADING = re.compile(r"^(#{1,6})\s+(.*?)\s*#*\s*$")


def strip_inline(text):
    """Reduce one line of Markdown to the text a reader sees."""
    text = MARKER.sub(" ", text)
    text = re.sub(r"<!--.*?-->", " ", text)
    text = re.sub(r"!\[([^\]]*)\]\([^)]*\)", r"\1", text)   # image -> alt text
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text)    # link -> link text
    text = re.sub(r"\[([^\]]*)\]\[[^\]]*\]", r"\1", text)   # reference link
    text = re.sub(r"<https?://[^>]+>", " ", text)           # autolink
    text = re.sub(r"</?[A-Za-z][^>]*>", " ", text)          # inline HTML tags
    # Inline code is kept verbatim: nothing inside it is Markdown syntax.
    code_spans = []
    def _keep(match):
        code_spans.append(match.group(1))
        return f"\x00{len(code_spans) - 1}\x00"
    text = re.sub(r"`([^`]*)`", _keep, text)
    text = re.sub(r"^\s{0,3}#{1,6}\s+", "", text)           # heading marks
    text = re.sub(r"^\s*>+\s?", "", text)                   # blockquote
    text = re.sub(r"^\s*([-*+]|\d+[.)])\s+", "", text)      # list markers
    text = re.sub(r"^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$", "", text)  # table rule
    text = text.replace("|", " ")
    text = re.sub(r"^\s*([-*_]\s*){3,}$", "", text)         # horizontal rule
    # Emphasis only when paired, so "snake_case" and "2*3*4" keep their characters.
    text = re.sub(r"(\*\*|__|~~)(.+?)\1", r"\2", text)
    text = re.sub(r"(?<!\w)\*(\S.*?\S|\S)\*(?!\w)", r"\1", text)
    text = re.sub(r"(?<!\w)_(\S.*?\S|\S)_(?!\w)", r"\1", text)
    text = re.sub(r"\x00(\d+)\x00", lambda m: code_spans[int(m.group(1))], text)
    return text


def words_of(text):
    # A word is a whitespace-separated token with at least one letter or digit,
    # which is how word processors count; a lone dash is not a word.
    return [t for t in text.split() if re.search(r"\w", t)]


def chars_of(text):
    # Characters including spaces, with every run of whitespace counted as one
    # space — how editors count a running text, independent of line wrapping.
    return len(re.sub(r"\s+", " ", text).strip())


class Section:
    def __init__(self, title):
        self.title = title
        self.text = []
        self.code_lines = 0
        self.code_text = []


def parse(lines):
    sections = [Section("(vor der ersten Überschrift)")]
    markers = []
    fence = None          # the opening fence string while inside a code block
    in_comment = False

    start = 0
    # YAML front matter: a "---" first line, closed within the first 50 lines,
    # with every non-empty line in between shaped like YAML ("key: value",
    # "- item", or an indented continuation). A "---" that opens an article as
    # a horizontal rule does not meet that shape and is left alone.
    FRONT_MATTER_MAX_LINES = 50
    if lines and lines[0].strip() == "---":
        for i in range(1, min(len(lines), FRONT_MATTER_MAX_LINES)):
            if lines[i].strip() in ("---", "..."):
                start = i + 1
                break
            if lines[i].strip() and not re.match(r"^(\s+\S|[\w-]+\s*:|-\s)", lines[i]):
                break

    for number, line in enumerate(lines[start:], start=start + 1):
        opener = FENCE.match(line)
        if fence is None and opener:
            fence = opener.group(1)
            continue
        if fence is not None:
            closer = opener.group(1) if opener else ""
            if closer[:1] == fence[:1] and len(closer) >= len(fence) \
                    and not line.strip(" ").rstrip("`~").strip():
                fence = None
                continue
            sections[-1].code_lines += 1
            sections[-1].code_text.append(line)
            continue

        if in_comment:
            if "-->" in line:
                in_comment = False
                line = line.split("-->", 1)[1]
            else:
                continue
        if "<!--" in line and "-->" not in line.split("<!--", 1)[1]:
            in_comment = True
            line = line.split("<!--", 1)[0]

        for match in MARKER.finditer(line):
            markers.append((number, match.group(0)))

        heading = HEADING.match(line)
        if heading and len(heading.group(1)) <= 2:
            sections.append(Section(strip_inline(heading.group(2)).strip()))
        sections[-1].text.append(strip_inline(line))

    return [s for s in sections if "".join(s.text).strip() or s.code_lines], markers


def measure(section, unit, include_code):
    text = "\n".join(section.text)
    if include_code:
        text += "\n" + "\n".join(section.code_text)
    return len(words_of(text)) if unit == "words" else chars_of(text)


def positive_int(value):
    number = int(value)
    if number <= 0:
        raise argparse.ArgumentTypeError(f"must be a positive number, got {value}")
    return number


def non_negative_float(value):
    number = float(value)
    if number < 0:
        raise argparse.ArgumentTypeError(f"must not be negative, got {value}")
    return number


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("article")
    parser.add_argument("--unit", choices=["words", "chars"], default="words")
    parser.add_argument("--target", type=positive_int,
                        help="target length in the chosen unit (must be > 0)")
    parser.add_argument("--tolerance", type=non_negative_float, default=10.0,
                        help="allowed deviation in percent (default 10)")
    parser.add_argument("--limit", type=positive_int,
                        help="hard ceiling in the chosen unit: fail above it regardless of tolerance")
    parser.add_argument("--include-code", action="store_true",
                        help="count fenced code toward the length")
    args = parser.parse_args()

    try:
        with open(args.article, encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except OSError as error:
        print(f"cannot read {args.article}: {error}", file=sys.stderr)
        return 2

    sections, markers = parse(lines)
    unit_label = "Wörter" if args.unit == "words" else "Zeichen inkl. Leerzeichen"

    all_text = "\n".join(t for s in sections for t in s.text)
    all_code = "\n".join(t for s in sections for t in s.code_text)
    words = len(words_of(all_text))
    chars = chars_of(all_text)
    chars_no_space = len(re.sub(r"\s", "", all_text))
    code_lines = sum(s.code_lines for s in sections)
    total = sum(measure(s, args.unit, args.include_code) for s in sections)

    print(f"Datei: {args.article}")
    print(f"Fließtext: {words} Wörter · {chars} Zeichen inkl. Leerzeichen · "
          f"{chars_no_space} ohne Leerzeichen")
    print(f"Code: {code_lines} Zeilen · {chars_of(all_code)} Zeichen "
          f"({'mitgezählt' if args.include_code else 'nicht mitgezählt'})")
    print()
    print(f"Abschnitte ({unit_label}):")
    width = max((len(s.title) for s in sections), default=10)
    for section in sections:
        code_note = f"  + {section.code_lines} Zeilen Code" if section.code_lines else ""
        print(f"  {section.title:<{width}}  {measure(section, args.unit, args.include_code):>6}{code_note}")
    print(f"  {'Summe':<{width}}  {total:>6}")

    print()
    if markers:
        print(f"Markierungen ({len(markers)}):")
        for number, text in markers:
            print(f"  Zeile {number}: {text}")
    else:
        print("Markierungen: keine")

    if args.target is None and args.limit is None:
        return 0

    target = args.target if args.target is not None else args.limit
    if args.limit is not None and target > args.limit:
        print(f"--target {target} liegt über --limit {args.limit}", file=sys.stderr)
        return 2

    low = target * (1 - args.tolerance / 100)
    high = target * (1 + args.tolerance / 100)
    if args.limit is not None:
        high = min(high, args.limit)
    deviation = (total - target) / target * 100
    verdict = "IN TOLERANCE" if low <= total <= high else "OUT OF TOLERANCE"
    print()
    limit_note = f", harte Grenze {args.limit}" if args.limit is not None else ""
    print(f"Ziel: {target} {unit_label} (erlaubt {round(low)}–{round(high)}{limit_note})")
    print(f"Ist: {total} ({deviation:+.1f} %) → {verdict}")
    return 0 if verdict == "IN TOLERANCE" else 1


if __name__ == "__main__":
    sys.exit(main())
