#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path
from typing import Iterable


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract commit sequence lines from emulator logs."
    )
    parser.add_argument(
        "logs",
        nargs="+",
        type=Path,
        help="Log file paths to process.",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        help="Directory to store extracted files. Defaults to each log's parent directory.",
    )
    parser.add_argument(
        "--suffix",
        default=".commit_seq.txt",
        help="Suffix appended to the log filename when generating output files.",
    )
    parser.add_argument(
        "--keep-extension",
        action="store_true",
        help="Append the suffix after the full filename instead of replacing the original extension.",
    )
    return parser.parse_args()


def extract_commit_lines(log_path: Path) -> list[str]:
    lines: list[str] = []
    with log_path.open("r", encoding="utf-8", errors="replace") as handle:
        for raw_line in handle:
            line = raw_line.rstrip("\n")
            if "commit pc" in line:
                lines.append(line)
    return lines


def build_output_path(
    log_path: Path, output_dir: Path | None, suffix: str, keep_extension: bool
) -> Path:
    base_dir = output_dir if output_dir is not None else log_path.parent
    if keep_extension:
        filename = f"{log_path.name}{suffix}"
    else:
        filename = f"{log_path.stem}{suffix}"
    return base_dir / filename


def ensure_parent(paths: Iterable[Path]) -> None:
    for path in paths:
        path.parent.mkdir(parents=True, exist_ok=True)


def main() -> int:
    args = parse_args()

    outputs = [
        build_output_path(log_path, args.output_dir, args.suffix, args.keep_extension)
        for log_path in args.logs
    ]
    ensure_parent(outputs)

    for log_path, output_path in zip(args.logs, outputs):
        if not log_path.is_file():
            raise FileNotFoundError(f"log file not found: {log_path}")

        commit_lines = extract_commit_lines(log_path)
        content = "\n".join(commit_lines)
        if commit_lines:
            content += "\n"
        output_path.write_text(content, encoding="utf-8")
        print(f"{log_path} -> {output_path} ({len(commit_lines)} commit lines)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
