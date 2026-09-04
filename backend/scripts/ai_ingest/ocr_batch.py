#!/usr/bin/env python3
"""OCR every page image in a book's page directory (render_pages.py's output) via a
vision-model API, and assemble the result into one Markdown file per book with
`<!-- page:N -->` markers — the exact format `fatawa.documents.original_text`
expects (see docs/features/ai-search-m5.0-spec.md §Data model).

Pluggable providers (mirrors this backend's EmbeddingProvider/AnswerProvider pattern
in backend/functions/api/ai_search/providers.ts) — pick with --provider:
    gemini    GEMINI_API_KEY     gemini-2.5-flash, vision
    mistral   MISTRAL_API_KEY    mistral-ocr-latest, purpose-built OCR
    anthropic ANTHROPIC_API_KEY  claude-sonnet-5, vision (highest quality, priciest)

Resumable and idempotent: a page whose output file already exists in --cache is
skipped, so a crashed or rate-limited run picks back up without re-paying for
already-OCR'd pages. Safe to Ctrl-C and rerun.

Usage (single book, once render_pages.py has produced the page images):
    export GEMINI_API_KEY=...
    python3 ocr_batch.py pages/<book-stem>/ --provider gemini --out markdown/<book-stem>.md \\
        --source-label "العقيدة/شرح ثلاثة الأصول - ابن عثيمين.pdf" --cache .ocr_cache/

Corpus-wide: shell out to this per book from a driver script (not included — the
pilot decides page-count/cost/concurrency before that's worth writing).
"""
from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

OCR_PROMPT = """اقرأ هذه الصورة لصفحة من كتاب عربي مطبوع وحوّلها إلى نص Markdown نظيف.

القواعد:
- انسخ النص كما هو تمامًا، بما في ذلك التشكيل الكامل إن وُجد، ورموز ﷺ/ﷻ/﴿﴾.
- حافظ على بنية الصفحة: العناوين كعناوين Markdown (##)، الفقرات كفقرات منفصلة.
- إن وُجدت أرقام هوامش (حواشي) في المتن، مثّلها كـ [^1] وضع نص الحاشية أسفل الصفحة
  بصيغة [^1]: نص الحاشية.
- احذف ترويسة الصفحة المتكررة (اسم الكتاب) وترقيم الصفحة الزخرفي من المتن — لا تحذف
  أرقام الآيات أو أرقام المسائل/الأسئلة، فهي جزء من المحتوى.
- لا تُترجم، ولا تُلخّص، ولا تُضف أي تعليق أو شرح من عندك. انسخ فقط.
- إن كانت الصفحة فارغة أو بيضاء تمامًا (كصفحة فاصل)، أعد النص: [صفحة فارغة]

أعد Markdown فقط، بلا أي مقدمة أو خاتمة من عندك."""

PAGE_NUM_RE = re.compile(r"-(\d+)\.png$")


def page_number(png_path: Path) -> int:
    m = PAGE_NUM_RE.search(png_path.name)
    if not m:
        raise ValueError(f"can't parse page number from {png_path.name}")
    return int(m.group(1))


def _post_json(url: str, headers: dict, body: dict, timeout: int = 120) -> dict:
    req = urllib.request.Request(
        url, data=json.dumps(body).encode("utf-8"), headers=headers, method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code} from {url}: {detail[:500]}") from e


def ocr_with_gemini(image_b64: str, api_key: str) -> str:
    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"gemini-2.5-flash:generateContent?key={api_key}"
    )
    body = {
        "contents": [{
            "parts": [
                {"text": OCR_PROMPT},
                {"inline_data": {"mime_type": "image/png", "data": image_b64}},
            ]
        }],
        "generationConfig": {"temperature": 0},
    }
    result = _post_json(url, {"content-type": "application/json"}, body)
    return result["candidates"][0]["content"]["parts"][0]["text"]


def ocr_with_anthropic(image_b64: str, api_key: str) -> str:
    url = "https://api.anthropic.com/v1/messages"
    headers = {
        "content-type": "application/json",
        "x-api-key": api_key,
        "anthropic-version": "2023-06-01",
    }
    body = {
        "model": "claude-sonnet-5",
        "max_tokens": 4096,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": image_b64}},
                {"type": "text", "text": OCR_PROMPT},
            ],
        }],
    }
    result = _post_json(url, headers, body)
    return "".join(b["text"] for b in result["content"] if b["type"] == "text")


def ocr_with_mistral(image_b64: str, api_key: str) -> str:
    # Mistral's dedicated OCR endpoint (not chat-completions) — returns structured
    # Markdown natively, so the shared OCR_PROMPT isn't sent; document_url accepts
    # a data: URI directly.
    url = "https://api.mistral.ai/v1/ocr"
    headers = {"content-type": "application/json", "authorization": f"Bearer {api_key}"}
    body = {
        "model": "mistral-ocr-latest",
        "document": {"type": "image_url", "image_url": f"data:image/png;base64,{image_b64}"},
    }
    result = _post_json(url, headers, body)
    return "\n\n".join(page.get("markdown", "") for page in result.get("pages", []))


PROVIDERS = {
    "gemini": (ocr_with_gemini, "GEMINI_API_KEY"),
    "anthropic": (ocr_with_anthropic, "ANTHROPIC_API_KEY"),
    "mistral": (ocr_with_mistral, "MISTRAL_API_KEY"),
}


def ocr_one_page(png_path: Path, provider: str, api_key: str, cache_dir: Path, retries: int = 3) -> tuple[int, str]:
    n = page_number(png_path)
    cache_file = cache_dir / f"{png_path.stem}.txt"
    if cache_file.exists():
        return n, cache_file.read_text(encoding="utf-8")

    fn, _ = PROVIDERS[provider]
    image_b64 = base64.b64encode(png_path.read_bytes()).decode("ascii")

    last_err: Exception | None = None
    for attempt in range(retries):
        try:
            text = fn(image_b64, api_key)
            cache_file.parent.mkdir(parents=True, exist_ok=True)
            cache_file.write_text(text, encoding="utf-8")
            return n, text
        except Exception as e:  # noqa: BLE001 — retry-all is intentional here
            last_err = e
            time.sleep(2 ** attempt)
    raise RuntimeError(f"page {n} ({png_path.name}) failed after {retries} attempts: {last_err}")


def run(book_dir: Path, provider: str, out_path: Path, source_label: str, cache_dir: Path, workers: int) -> None:
    _, env_key = PROVIDERS[provider]
    api_key = os.environ.get(env_key)
    if not api_key:
        sys.exit(f"error: {env_key} is not set (needed for --provider {provider})")

    pages = sorted(book_dir.glob("*.png"), key=page_number)
    if not pages:
        sys.exit(f"error: no .png pages found in {book_dir} — run render_pages.py first")

    cache_dir.mkdir(parents=True, exist_ok=True)
    results: dict[int, str] = {}
    failures: list[str] = []

    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(ocr_one_page, p, provider, api_key, cache_dir): p for p in pages}
        done = 0
        for fut in as_completed(futures):
            done += 1
            try:
                n, text = fut.result()
                results[n] = text
            except Exception as e:  # noqa: BLE001 — collected, not fatal to the batch
                failures.append(str(e))
            print(f"\r{book_dir.name}: {done}/{len(pages)} pages OCR'd "
                  f"({len(failures)} failed)", end="", file=sys.stderr)
    print(file=sys.stderr)

    if failures:
        print(f"warning: {len(failures)} page(s) failed and are omitted from the "
              f"assembled Markdown — rerun the same command to retry only those "
              f"(cache skips the rest):", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        f.write(f"<!-- source: {source_label} -->\n")
        for n in sorted(results):
            f.write(f"\n<!-- page:{n} -->\n\n{results[n].strip()}\n")

    print(f"assembled {len(results)}/{len(pages)} pages -> {out_path}", file=sys.stderr)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("book_dir", type=Path, help="directory of page PNGs from render_pages.py")
    parser.add_argument("--provider", choices=PROVIDERS.keys(), required=True)
    parser.add_argument("--out", type=Path, required=True, help="assembled per-book Markdown output path")
    parser.add_argument("--source-label", required=True, help="original PDF path/name, stored as a header comment")
    parser.add_argument("--cache", type=Path, default=Path(".ocr_cache"), help="per-page OCR cache (resumability)")
    parser.add_argument("--workers", type=int, default=4, help="concurrent page requests")
    args = parser.parse_args()
    run(args.book_dir, args.provider, args.out, args.source_label, args.cache, args.workers)
