"""Checks on the canonical reviewer export; no app screenshot generation."""
import importlib.util
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("review_document", REPO / "scripts/render-review-document.py")
RENDERER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RENDERER)


class ReviewDocumentTests(unittest.TestCase):
    def test_export_is_reproducible_and_demo_first(self):
        source = REPO / "docs/app-review-demo.md"
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            RENDERER.generate(source, output, "1.0", "7")
            initial = (output / "FENR-review.pdf").read_bytes()
            notes = (output / "review-notes.txt").read_text()
            self.assertIn("Explore demo > Start demo", notes)
            self.assertIn("No motorcycle", notes)
            self.assertNotIn("Copy & Pair", notes)
            self.assertNotIn("Engineering validation", notes)
            self.assertLessEqual(len(notes), 4000)
            RENDERER.generate(source, output, "1.0", "7")
            self.assertEqual(initial, (output / "FENR-review.pdf").read_bytes())
            RENDERER.generate(source, output, "1.0", "8")
            self.assertNotEqual(initial, (output / "FENR-review.pdf").read_bytes())

    def test_private_engineering_appendix_never_enters_export(self):
        public = "# Guide\n\n## Access\nExplore demo\n\n## Demo behavior\nSimulated\n"
        result = RENDERER.reviewer_source(public + "\n## Engineering validation\nINTERNAL_ONLY\n")
        self.assertNotIn("INTERNAL_ONLY", result)
        self.assertNotIn("Engineering validation", result)

    def test_links_and_reserved_characters_are_renderable(self):
        result = RENDERER.inline("Copy & Pair at https://fenr.to/privacy")
        self.assertIn("&amp;", result)
        self.assertIn('href="https://fenr.to/privacy"', result)

    def test_markdown_url_label_does_not_create_nested_links(self):
        url = "https://fenr.to/privacy"
        result = RENDERER.inline(f"[{url}]({url})")
        self.assertEqual(result, f'<link href="{url}" color="#146345">{url}</link>')


if __name__ == "__main__":
    unittest.main()
