from __future__ import annotations

import argparse
import base64
import json
import os
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def parse_timestamp(value: str) -> datetime | None:
    if not value:
        return None
    normalized = value.replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=timezone.utc)
    return parsed.astimezone(timezone.utc)


def safe_timestamp(value: str) -> str:
    parsed = parse_timestamp(value)
    if parsed == None:
        return "unknown_time"
    return parsed.strftime("%Y%m%dT%H%M%SZ")


def safe_id(value: str) -> str:
    allowed = []
    for char in value:
        allowed.append(char if char.isalnum() or char in ["_", "-"] else "_")
    result = "".join(allowed).strip("_")
    return result if result else "image"


def default_sessions_root() -> Path:
    codex_home = os.environ.get("CODEX_HOME")
    if not codex_home:
        user_profile = os.environ.get("USERPROFILE")
        if user_profile:
            codex_home = str(Path(user_profile) / ".codex")
        else:
            codex_home = str(Path.home() / ".codex")
    return Path(codex_home) / "sessions"


def latest_session() -> Path:
    root = default_sessions_root()
    candidates = [path for path in root.rglob("*.jsonl") if path.is_file()]
    if not candidates:
        raise FileNotFoundError(f"{root}: no Codex session jsonl files found")
    return max(candidates, key=lambda path: path.stat().st_mtime)


def iter_image_results(session: Path, after: datetime | None) -> Iterable[tuple[str, str, str]]:
    seen: set[str] = set()
    with session.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            try:
                record = json.loads(line)
            except json.JSONDecodeError:
                continue
            timestamp = str(record.get("timestamp", ""))
            parsed_ts = parse_timestamp(timestamp)
            if after is not None and parsed_ts is not None and parsed_ts < after:
                continue
            payload = record.get("payload", {})
            if not isinstance(payload, dict):
                continue
            if payload.get("type") != "image_generation_end":
                continue
            encoded = payload.get("result", "")
            if not isinstance(encoded, str) or not encoded.startswith("iVBOR"):
                continue
            image_id = str(payload.get("call_id", "") or payload.get("id", ""))
            dedupe_key = image_id or encoded[:80]
            if dedupe_key in seen:
                continue
            seen.add(dedupe_key)
            yield timestamp, image_id, encoded


def decode_png(encoded: str) -> bytes:
    data = base64.b64decode(encoded, validate=True)
    if not data.startswith(PNG_SIGNATURE):
        raise ValueError("decoded result is not a PNG")
    return data


def extract(session: Path, out_dir: Path, after: datetime | None, prefix: str, limit: int) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    for timestamp, image_id, encoded in iter_image_results(session, after):
        png = decode_png(encoded)
        stem = f"{prefix}{safe_timestamp(timestamp)}_{safe_id(image_id)}"
        path = out_dir / f"{stem}.png"
        suffix = 2
        while path.exists():
            path = out_dir / f"{stem}_{suffix}.png"
            suffix += 1
        path.write_bytes(png)
        written.append(path)
        if limit > 0 and len(written) >= limit:
            break
    return written


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract image_gen PNG results embedded in Codex session JSONL logs.")
    parser.add_argument("--session", type=Path, default=None, help="Codex session JSONL. Defaults to the latest session.")
    parser.add_argument("--out-dir", type=Path, required=True, help="Directory for recovered PNG files.")
    parser.add_argument("--after", default="", help="Only extract records at or after this UTC timestamp.")
    parser.add_argument("--prefix", default="", help="Filename prefix for recovered PNG files.")
    parser.add_argument("--limit", type=int, default=0, help="Maximum number of images to extract. 0 means no limit.")
    args = parser.parse_args()

    session = args.session if args.session is not None else latest_session()
    after = parse_timestamp(args.after) if args.after else None
    written = extract(session, args.out_dir, after, args.prefix, args.limit)
    for path in written:
        print(path)
    if not written:
        print("No image_generation_end PNG results found.")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
