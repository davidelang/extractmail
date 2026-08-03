"""Load extractors/*.yaml type registry (detect/reject metadata + impl pointer)."""
from __future__ import annotations

from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
EXTRACTORS = ROOT / "extractors"


def _simple_yaml_load(text: str) -> dict[str, Any]:
    """Minimal YAML subset for our extractor files (no full PyYAML required)."""
    try:
        import yaml  # type: ignore

        data = yaml.safe_load(text)
        return data if isinstance(data, dict) else {}
    except Exception:
        pass
    # Fallback: only extract top-level scalar keys we need
    out: dict[str, Any] = {}
    for line in text.splitlines():
        if not line or line.lstrip().startswith("#") or line.startswith(" ") or line.startswith("\t"):
            continue
        if ":" not in line:
            continue
        k, v = line.split(":", 1)
        k = k.strip()
        v = v.strip().strip('"').strip("'")
        if k and v and not v.startswith("|") and not v.startswith(">"):
            out[k] = v
    return out


def load_type_registry() -> dict[str, dict[str, Any]]:
    """Map type key → yaml document (type, brand, impl, module, export, …)."""
    reg: dict[str, dict[str, Any]] = {}
    if not EXTRACTORS.is_dir():
        return reg
    for path in sorted(EXTRACTORS.glob("*.yaml")):
        data = _simple_yaml_load(path.read_text(encoding="utf-8"))
        key = str(data.get("type") or path.stem)
        data["_path"] = str(path)
        reg[key] = data
    return reg


def known_types() -> list[str]:
    return sorted(load_type_registry().keys())


def resolve_impl(type_key: str) -> dict[str, Any] | None:
    reg = load_type_registry()
    if type_key in ("auto", "", None):  # type: ignore[comparison-overlap]
        return {"type": "auto", "impl": "reference-js"}
    return reg.get(type_key)
