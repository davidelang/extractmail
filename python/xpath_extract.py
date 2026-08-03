"""CSS/XPath field extraction for YAML type packs (stdlib-first)."""

from __future__ import annotations

import re
from html.parser import HTMLParser
from typing import Any


class _TextCollector(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.parts: list[str] = []
        self._skip = 0

    def handle_starttag(self, tag: str, attrs) -> None:
        if tag in ("script", "style"):
            self._skip += 1

    def handle_endtag(self, tag: str) -> None:
        if tag in ("script", "style") and self._skip:
            self._skip -= 1

    def handle_data(self, data: str) -> None:
        if self._skip:
            return
        t = data.strip()
        if t:
            self.parts.append(t)


def html_to_text(html: str) -> str:
    p = _TextCollector()
    try:
        p.feed(html)
    except Exception:
        return re.sub(r"<[^>]+>", " ", html)
    return "\n".join(p.parts)


def extract_field(html: str, field_cfg: dict[str, Any], headers: dict[str, str] | None = None) -> str | None:
    """Return string value for one field config, or None."""
    strategy = str(field_cfg.get("strategy") or field_cfg.get("impl") or "").lower()
    headers = headers or {}

    if strategy in ("header",):
        name = str(field_cfg.get("name") or "Date")
        key = name.lower()
        for k, v in headers.items():
            if k.lower() == key:
                return v
        return headers.get(name)

    selector = str(field_cfg.get("selector") or field_cfg.get("xpath") or field_cfg.get("css") or "")
    if not selector:
        return None

    # Prefer lxml / bs4 when available (only if selector looks like real CSS/XPath)
    looks_like_selector = any(ch in selector for ch in "./#[]@()") or strategy == "xpath"
    if strategy in ("xpath", "css") and looks_like_selector:
        try:
            from lxml import html as lhtml  # type: ignore

            tree = lhtml.fromstring(html)
            if strategy == "xpath":
                nodes = tree.xpath(selector)
            else:
                nodes = tree.cssselect(selector)
            if nodes:
                n0 = nodes[0]
                text = n0.text_content() if hasattr(n0, "text_content") else str(n0)
                val = " ".join(str(text).split())
                if val:
                    return val
        except Exception:
            pass
        try:
            from bs4 import BeautifulSoup  # type: ignore

            soup = BeautifulSoup(html, "html.parser")
            if strategy == "css":
                el = soup.select_one(selector)
                if el:
                    val = " ".join(el.get_text(" ", strip=True).split())
                    if val:
                        return val
        except Exception:
            pass

    # Stdlib fallback: treat selector as case-insensitive label near a value
    # e.g. selector "Total" finds nearby money amount
    text = html_to_text(html)
    label = selector.strip("/[]@=.\"' ")
    if not label:
        return None
    # Prefer volume patterns when the label looks like gallons
    if re.search(r"gal", label, flags=re.I):
        gal = re.search(
            re.escape(label) + r".{0,80}?(\d+(?:\.\d+)?)\s*(?:gal|gallon)?",
            text,
            flags=re.I | re.S,
        )
        if gal:
            return gal.group(1)
    money = re.search(
        re.escape(label) + r".{0,80}?(\$?\s*\d{1,3}(?:,\d{3})*(?:\.\d{1,3})?)",
        text,
        flags=re.I | re.S,
    )
    if money:
        return money.group(1).replace("$", "").replace(",", "").strip()
    gal = re.search(
        re.escape(label) + r".{0,80}?(\d+(?:\.\d+)?)\s*(?:gal|gallon)",
        text,
        flags=re.I | re.S,
    )
    if gal:
        return gal.group(1)
    num = re.search(
        re.escape(label) + r".{0,40}?(\d+(?:\.\d+)?)",
        text,
        flags=re.I | re.S,
    )
    if num:
        return num.group(1)
    return None


def extract_from_yaml_fields(
    html: str,
    fields: dict[str, Any],
    headers: dict[str, str] | None = None,
) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for name, cfg in (fields or {}).items():
        if not isinstance(cfg, dict):
            continue
        if str(cfg.get("strategy") or "").lower() in ("reference_js", "reference-js", "external"):
            continue
        val = extract_field(html, cfg, headers)
        if val is not None and val != "":
            out[name] = val
    return out
