"""Export NLLB-200 to ONNX and quantize to int8 for on-device use.

Usage (from model_tools/):
    uv sync --extra export
    uv run export-nllb --out ../models/nllb-600m-onnx-int8
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

DEFAULT_MODEL = "facebook/nllb-200-distilled-600M"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--out", type=Path, default=Path("../models/nllb-600m-onnx-int8"))
    args = parser.parse_args()

    try:
        from onnxruntime.quantization import QuantType, quantize_dynamic
        from optimum.onnxruntime import ORTModelForSeq2SeqLM
        from transformers import AutoTokenizer
    except ImportError as exc:
        raise SystemExit("Export deps missing. Run: uv sync --extra export") from exc

    out: Path = args.out
    fp32 = out.with_name(out.name + "-fp32")

    print(f"Exporting {args.model} to ONNX (fp32) ...")
    ORTModelForSeq2SeqLM.from_pretrained(args.model, export=True).save_pretrained(fp32)

    print("Saving tokenizer ...")
    AutoTokenizer.from_pretrained(args.model).save_pretrained(out)

    print("Quantizing to int8 ...")
    for onnx_file in sorted(fp32.glob("*.onnx")):
        quantize_dynamic(onnx_file, out / onnx_file.name, weight_type=QuantType.QInt8)
        size_mb = (out / onnx_file.name).stat().st_size / 1e6
        print(f"  {onnx_file.name}: {size_mb:.0f} MB")
    for config in fp32.glob("*.json"):
        shutil.copy(config, out / config.name)

    shutil.rmtree(fp32)
    print(f"Done: {out}")


if __name__ == "__main__":
    main()
