#!/usr/bin/env python3
"""Render the public reviewer portion of the canonical guide. Never capture app UI."""
import argparse
import html
import re
from pathlib import Path

from reportlab import rl_config
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import Paragraph, SimpleDocTemplate


def reviewer_source(source):
    return source.split("\n## Engineering validation", 1)[0].strip() + "\n"


def inline(text):
    text = html.escape(text, quote=True)
    text = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", text)
    text = re.sub(r"`([^`]+)`", r"\1", text)
    text = re.sub(
        r"\[([^]]+)\]\((https://[^)]+)\)|(https://[A-Za-z0-9./_-]+)",
        lambda match: '<link href="{}" color="#146345">{}</link>'.format(
            match[2] or match[3], match[1] or match[3]),
        text,
    )
    text = re.sub(r"\[([^]]+)\]\([^)]+\)", r"\1", text)
    return text


def generate(source_path, output_dir, version, build):
    source = reviewer_source(source_path.read_text())
    for heading in ("## Access", "## About the motorcycle connection", "## Demo behavior"):
        if heading not in source:
            raise ValueError("Canonical guide is missing a required reviewer section")
    output_dir.mkdir(parents=True, exist_ok=True)
    pdf_path = output_dir / "FENR-review.pdf"
    rl_config.invariant = 1
    body = ParagraphStyle("FENRBody", fontName="Helvetica", fontSize=10, leading=15,
                          spaceAfter=8, textColor=colors.HexColor("#26332f"))
    heading = ParagraphStyle("FENRHeading", parent=body, fontName="Helvetica-Bold",
                             fontSize=13, leading=17, spaceBefore=14, spaceAfter=7, keepWithNext=True)
    title = ParagraphStyle("FENRTitle", parent=heading, fontSize=24, leading=29, spaceAfter=12)
    bullet = ParagraphStyle("FENRBullet", parent=body, leftIndent=12, firstLineIndent=-8)
    subtitle = ParagraphStyle("FENRSubtitle", parent=body, textColor=colors.HexColor("#146345"), spaceAfter=18)
    story = [Paragraph("FENR - App Review Guide", title),
             Paragraph(f"iPhone | Version {version} | Build {build}", subtitle)]
    paragraphs = source.split("\n\n")
    for paragraph in paragraphs:
        if paragraph.startswith("# "):
            continue
        if paragraph.startswith("## "):
            story.append(Paragraph(inline(paragraph[3:]), heading))
        elif paragraph.startswith("- ") or re.match(r"\d+\. ", paragraph):
            items = re.split(r"\n(?=- |\d+\. )", paragraph)
            for item in items:
                story.append(Paragraph(inline(" ".join(item.splitlines())), bullet))
        else:
            text = " ".join(paragraph.splitlines())
            story.append(Paragraph(inline(text), body))

    def footer(canvas, doc):
        canvas.saveState()
        canvas.setStrokeColor(colors.HexColor("#d7e1dc"))
        canvas.line(48, 43, 547, 43)
        canvas.setFont("Helvetica", 8)
        canvas.setFillColor(colors.HexColor("#61746a"))
        canvas.drawString(48, 29, f"FENR | {version} ({build}) | Reviewer instructions")
        canvas.drawRightString(547, 29, str(doc.page))
        canvas.restoreState()

    doc = SimpleDocTemplate(str(pdf_path), pagesize=(595.28, 841.89),
                            rightMargin=48, leftMargin=48, topMargin=45, bottomMargin=60,
                            title="FENR - App Review Guide", author="FENR", pageCompression=1)
    doc.build(story, onFirstPage=footer, onLaterPages=footer)
    access = source.split("## Access\n", 1)[1].split("\n## ", 1)[0].strip()
    intro = source.split("\n## ", 1)[0].split("\n\n", 1)[1].strip()
    notes = (f"FENR {version} (build {build})\n\n{intro}\n\n"
             f"DEMO ACCESS\n{access}\n\n"
             "See the attached FENR review PDF for the demo walkthrough, expected results, "
             "and permissions. No demo account credentials are required.\n")
    notes = re.sub(r"\*\*(.*?)\*\*", r"\1", notes)
    if len(notes) > 4000:
        raise ValueError("Generated App Review Notes exceed 4000 characters")
    (output_dir / "review-notes.txt").write_text(notes)
    print(f"Generated {pdf_path} and review-notes.txt")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--build", required=True)
    args = parser.parse_args()
    if not all(re.fullmatch(r"[0-9]+(?:\.[0-9]+){0,2}", value) for value in (args.version, args.build)):
        parser.error("Invalid version or build number")
    generate(args.source, args.output_dir, args.version, args.build)


if __name__ == "__main__":
    main()
