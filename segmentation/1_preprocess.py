#!/usr/bin/env python3
"""
Step 1: Image preprocessing for iMGL morphological profiling.

Applies a fixed sequence of PIL filters (UnsharpMask + GaussianBlur) to raw
phase-contrast TIFFs to enhance cell boundaries before Cellpose-SAM segmentation.

Usage:
    python 1_preprocess.py --input <raw_dir> --output <filtered_dir>

Parameters are frozen to match the published pipeline (see params.yml).
"""
import argparse
import sys
from pathlib import Path

from PIL import Image, ImageFilter


# Frozen preprocessing parameters (do not modify; see params.yml)
UNSHARP_RADIUS = 10
UNSHARP_PERCENT = 100
UNSHARP_THRESHOLD = 0
BLUR_RADIUS = 0.4
OUTPUT_SUFFIX = "_filt"


def parse_args():
    parser = argparse.ArgumentParser(
        description="Preprocess phase-contrast TIFFs prior to Cellpose-SAM segmentation."
    )
    parser.add_argument(
        "--input", "-i", required=True, type=Path,
        help="Directory containing raw .tif/.tiff images",
    )
    parser.add_argument(
        "--output", "-o", required=True, type=Path,
        help="Directory where filtered images will be written",
    )
    parser.add_argument(
        "--overwrite", action="store_true",
        help="Re-process images even if the output already exists",
    )
    parser.add_argument(
        "--progress-every", type=int, default=25,
        help="Print progress every N images (default: 25)",
    )
    return parser.parse_args()


def preprocess_one(in_path: Path, out_path: Path) -> None:
    """Apply UnsharpMask + GaussianBlur to a single TIFF."""
    with Image.open(in_path) as im:
        # First frame only (multi-page TIFFs)
        try:
            im.seek(0)
        except (EOFError, AttributeError):
            pass

        # Convert to 8-bit grayscale (raw GUI exports may be RGB)
        if im.mode != "L":
            im = im.convert("L")

        im = im.filter(
            ImageFilter.UnsharpMask(
                radius=UNSHARP_RADIUS,
                percent=UNSHARP_PERCENT,
                threshold=UNSHARP_THRESHOLD,
            )
        )
        im = im.filter(ImageFilter.GaussianBlur(radius=BLUR_RADIUS))
        im.save(out_path)


def main():
    args = parse_args()

    in_dir: Path = args.input
    out_dir: Path = args.output

    if not in_dir.is_dir():
        sys.exit(f"ERROR: input directory does not exist: {in_dir}")

    out_dir.mkdir(parents=True, exist_ok=True)

    images = sorted(
        p for p in in_dir.iterdir()
        if p.is_file() and p.suffix.lower() in (".tif", ".tiff")
    )
    print(f"Found {len(images)} TIFFs in {in_dir}", flush=True)

    if not images:
        sys.exit("ERROR: no .tif/.tiff files found in input directory.")

    done = skipped = failed = 0
    for p in images:
        out_path = out_dir / f"{p.stem}{OUTPUT_SUFFIX}.tif"

        if out_path.exists() and not args.overwrite:
            skipped += 1
            continue

        try:
            preprocess_one(p, out_path)
            done += 1
            if done % args.progress_every == 0:
                print(
                    f"[ok={done} skip={skipped} fail={failed}] last={p.name}",
                    flush=True,
                )
        except Exception as e:
            failed += 1
            print(f"FAILED {p.name}: {e!r}", flush=True)

    print(
        f"\nFinished: ok={done}, skipped={skipped}, failed={failed}",
        flush=True,
    )

    if failed > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
