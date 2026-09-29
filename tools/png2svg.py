#!/usr/bin/env python3
"""
png2svg.py — PNG → SVG vector converter for icon sets.

Pipeline:
  1. (optional) flatten alpha onto a solid background (default: white) so the
     traced result has a clean canvas instead of relying on a rasterized alpha
     channel.
  2. (optional) Lanczos upscale (default: auto) — only sources shorter than
     128px get blown up (32px -> 4x). Upscaling an already-large icon triples
     file size with no visible gain, so `--upscale auto` is the sane default.
  3. vtracer (Rust, visioncortex) — color-aware, hierarchical clustering.
     Tuned defaults below produce clean flat-color icons with sensible file
     sizes. Override any parameter from the CLI.
  4. (optional) scour (SVG Cleaner / SVGO equivalent for Python) — removes
     editor metadata, decimates redundant precision, often 30-60% smaller.

Usage:
  python png2svg.py SRC.png [DST.svg]
  python png2svg.py ./icon/*.png                  # batch
  python png2svg.py ./icon/AliPay.png -o out.svg  # custom output
  python png2svg.py in.png --colormode binary --filter-speckle 2
  python png2svg.py in.png --no-optimize          # keep raw vtracer output

Designed to run identically in CI (GitHub Actions) and locally.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

import vtracer
from PIL import Image

try:
    from scour.scour import scourString
    SCOUR_AVAILABLE = True
except Exception:
    SCOUR_AVAILABLE = False


# ---------- core ----------------------------------------------------------

def flatten_alpha(img: Image.Image, bg: tuple[int, int, int, int] | str) -> Image.Image:
    """Composite RGBA / LA / P images onto a solid background."""
    if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
        rgba = img.convert("RGBA")
        if isinstance(bg, str):
            from PIL import ImageColor
            bg = ImageColor.getcolor(bg, "RGBA")
        canvas = Image.new("RGBA", rgba.size, bg)
        canvas.alpha_composite(rgba)
        return canvas.convert("RGB")
    if img.mode != "RGB":
        return img.convert("RGB")
    return img


def resolve_upscale(img: Image.Image, requested: str | int, target: int = 128) -> int:
    """'auto' keeps native resolution for already-large icons and only blows up
    genuinely tiny sources, which is where Lanczos upscaling actually helps the
    tracer. Upscaling a 144px icon to 288px triples file size for no visible gain."""
    if isinstance(requested, str) and requested == "auto":
        shortest = min(img.size)
        if shortest <= 0:
            return 1
        return max(1, target // shortest)
    return max(1, int(requested))


def upscale(img: Image.Image, factor: int) -> Image.Image:
    if factor <= 1:
        return img
    w, h = img.size
    return img.resize((w * factor, h * factor), Image.LANCZOS)


def trace(
    png_path: Path,
    out_path: Path,
    *,
    colormode: str,
    hierarchical: str,
    mode: str,
    bg: str,
    upscale_factor: str | int,
    upscale_target: int,
    filter_speckle: int,
    color_precision: int,
    layer_difference: int,
    corner_threshold: int,
    length_threshold: float,
    splice_threshold: int,
    path_precision: int,
    max_iterations: int,
    optimize: bool,
) -> tuple[int, int]:
    """Convert one PNG to SVG. Returns (input_bytes, output_bytes)."""
    if not png_path.is_file():
        raise FileNotFoundError(png_path)

    img = Image.open(png_path)
    img.load()
    in_bytes = png_path.stat().st_size

    img = flatten_alpha(img, bg)
    factor = resolve_upscale(img, upscale_factor, upscale_target)
    img = upscale(img, factor)

    # vtracer consumes a raster file path, so write the preprocessed buffer
    # to a temp file next to the output.
    tmp_path = out_path.with_suffix(".tmp.png")
    img.save(tmp_path, format="PNG", optimize=True)

    try:
        vtracer.convert_image_to_svg_py(
            str(tmp_path),
            str(out_path),
            colormode=colormode,
            hierarchical=hierarchical,
            mode=mode,
            filter_speckle=filter_speckle,
            color_precision=color_precision,
            layer_difference=layer_difference,
            corner_threshold=corner_threshold,
            length_threshold=length_threshold,
            splice_threshold=splice_threshold,
            path_precision=path_precision,
            max_iterations=max_iterations,
        )
    finally:
        try:
            tmp_path.unlink()
        except OSError:
            pass

    if optimize:
        if not SCOUR_AVAILABLE:
            print("WARN: scour not installed, skipping optimization", file=sys.stderr)
        else:
            with open(out_path, "r", encoding="utf-8") as f:
                svg = f.read()
            optimized = scourString(
                svg,
                options={
                    "enable-id-stripping": True,
                    "enable-comment-stripping": True,
                    "shorten-ids": True,
                    "remove-metadata": True,
                    "remove-descriptive-elements": True,
                    "strip-xml-prolog": True,
                    "remove-unused-defs": True,
                    "remove-raster": True,
                    "enable-viewboxing": True,
                    "number-precision": max(1, path_precision - 1),
                },
            )
            with open(out_path, "w", encoding="utf-8") as f:
                f.write(optimized)

    out_bytes = out_path.stat().st_size
    return in_bytes, out_bytes


# ---------- CLI -----------------------------------------------------------

def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Convert PNG icons to SVG via vtracer.")
    p.add_argument("inputs", nargs="+", help="Input PNG file(s).")
    p.add_argument("-o", "--output", help="Output SVG file (single input only).")
    p.add_argument("--out-dir", help="Output directory (batch). Default: alongside input.")
    p.add_argument(
        "--colormode",
        choices=["color", "binary"],
        default="color",
        help="'color' for multi-color icons, 'binary' for monochrome.",
    )
    p.add_argument("--hierarchical", choices=["stacked", "cutout"], default="stacked")
    p.add_argument("--mode", choices=["spline", "polygon", "none"], default="spline")
    p.add_argument("--bg", default="white", help="Background color for alpha flattening (name or #rrggbb).")
    p.add_argument(
        "--upscale",
        default="auto",
        help="Lanczos upscale factor before tracing. 'auto' (default) only upscales "
             "sources shorter than 128px, e.g. 32px -> 4x, 64px -> 2x, 144px -> 1x. "
             "Pass an integer to force a fixed factor.",
    )
    p.add_argument("--upscale-target", type=int, default=128, help="Target short side in px for --upscale auto (default 128).")
    p.add_argument("--filter-speckle", type=int, default=4, help="Discard clusters smaller than N px (default 4).")
    p.add_argument("--color-precision", type=int, default=7, help="Distinct color layers; 1-8 (default 7).")
    p.add_argument("--layer-difference", type=int, default=12, help="Color delta for new layer (default 12).")
    p.add_argument("--corner-threshold", type=int, default=60, help="Spline corner angle in degrees (default 60).")
    p.add_argument("--length-threshold", type=float, default=4.0, help="Min path length; 3.5-10 (default 4.0).")
    p.add_argument("--splice-threshold", type=int, default=45, help="Max bend for spline merge (default 45).")
    p.add_argument("--path-precision", type=int, default=2, help="Decimal digits in path data (default 2).")
    p.add_argument("--max-iterations", type=int, default=10, help="vtracer iterative refinement rounds (default 10).")
    p.add_argument("--no-optimize", action="store_true", help="Skip scour post-optimization.")
    p.add_argument("--overwrite", action="store_true", help="Overwrite existing SVG.")
    p.add_argument("--quiet", action="store_true")
    args = p.parse_args(argv)

    optimize = not args.no_optimize
    overwrite = args.overwrite or args.output is not None  # explicit output implies intent

    targets: list[tuple[Path, Path]] = []
    if args.output:
        if len(args.inputs) != 1:
            p.error("--output requires exactly one input")
        targets.append((Path(args.inputs[0]), Path(args.output)))
    else:
        out_dir = Path(args.out_dir) if args.out_dir else None
        for raw in args.inputs:
            src = Path(raw)
            if not src.is_file():
                print(f"skip (not a file): {src}", file=sys.stderr)
                continue
            dst = src.with_suffix(".svg") if out_dir is None else out_dir / (src.stem + ".svg")
            targets.append((src, dst))

    if not targets:
        return 1

    rc = 0
    for src, dst in targets:
        if dst.exists() and not overwrite:
            print(f"skip (exists, use --overwrite): {dst}", file=sys.stderr)
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        try:
            in_b, out_b = trace(
                src, dst,
                colormode=args.colormode,
                hierarchical=args.hierarchical,
                mode=args.mode,
                bg=args.bg,
                upscale_factor=args.upscale,
                upscale_target=args.upscale_target,
                filter_speckle=args.filter_speckle,
                color_precision=args.color_precision,
                layer_difference=args.layer_difference,
                corner_threshold=args.corner_threshold,
                length_threshold=args.length_threshold,
                splice_threshold=args.splice_threshold,
                path_precision=args.path_precision,
                max_iterations=args.max_iterations,
                optimize=optimize,
            )
        except Exception as e:
            print(f"FAIL {src}: {e}", file=sys.stderr)
            rc = 1
            continue
        if not args.quiet:
            pct = (out_b / in_b * 100) if in_b else 0
            print(f"{src.name}: {in_b:,}B PNG -> {out_b:,}B SVG ({pct:.0f}%)")

    return rc


if __name__ == "__main__":
    raise SystemExit(main())