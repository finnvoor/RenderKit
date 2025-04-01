#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "numpy",
#     "pillow",
# ]
# ///
from PIL import Image
import numpy as np
import sys
import os
import argparse


def parse_cube_file(cube_path):
    with open(cube_path, "r") as f:
        lines = f.readlines()

    size = None
    lut_data = []

    for line in lines:
        line = line.strip()
        if line.startswith("LUT_3D_SIZE"):
            size = int(line.split()[-1])
        elif (
            line
            and not line.startswith("#")
            and not line.startswith("TITLE")
            and not line.startswith("DOMAIN_MIN")
            and not line.startswith("DOMAIN_MAX")
            and not line.startswith("LUT")
        ):
            r, g, b = map(float, line.split())
            lut_data.append([r, g, b])

    if not size or len(lut_data) != size**3:
        raise ValueError("Invalid .cube file format")

    return np.array(lut_data).reshape(size, size, size, 3)


def apply_cube_lut(image, lut_data):
    # Normalize image to 0-1
    img_float = np.array(image).astype(np.float32) / 255.0

    # Get LUT dimensions
    size = lut_data.shape[0]

    # Scale input coordinates to LUT indices
    scaled = img_float * (size - 1)

    # Get lower and upper indices for interpolation
    lower = np.floor(scaled).astype(int)
    # Clamp indices to valid range
    lower = np.clip(lower, 0, size - 1)

    # Get interpolation weights
    weights = scaled - lower

    # Perform trilinear interpolation
    result = np.zeros_like(img_float)
    for i in range(2):
        for j in range(2):
            for k in range(2):
                # Swap the order of indices to match Core Image's RGB ordering
                idx = np.clip(lower + np.array([i, j, k]), 0, size - 1)
                w = np.prod(np.where([i, j, k], weights, 1 - weights), axis=-1)[
                    ..., np.newaxis
                ]
                # Access LUT data with reversed indices to match Core Image's RGB ordering
                result += w * lut_data[idx[..., 2], idx[..., 1], idx[..., 0]]

    # Convert back to 0-255 range
    return Image.fromarray((result * 255).astype(np.uint8))


def convert_lut(input_path, output_path):
    # Check if input is a .cube file
    if input_path.lower().endswith(".cube"):
        reference_path = os.path.join(os.path.dirname(__file__), "ReferenceLUT.png")
        if not os.path.exists(reference_path):
            raise FileNotFoundError("ReferenceLUT.png not found in script directory")

        # Load and apply the cube file
        reference_img = Image.open(reference_path)
        lut_data = parse_cube_file(input_path)
        result = apply_cube_lut(reference_img, lut_data)
        result.save(output_path)
        return

    img = Image.open(input_path)
    width, height = img.size

    if width != height:
        raise ValueError("Input image must be square")

    # For 512x512 image:
    # - Each cube should be 64x64 (since 512/8 = 64)
    # - Grid will be 8x8 cubes
    grid_size = 8
    cube_size = width // grid_size  # For 512x512, this will be 64

    # Reshape image pixels to 4D: [grid_y, grid_x, cube_y, cube_x, RGB]
    pixels = np.array(img)
    pixels = pixels.reshape(grid_size, cube_size, grid_size, cube_size, 3)

    # Rearrange to match CIColorCube format (B varies fastest, then G, then R)
    # Convert each cube into a horizontal strip
    pixels = pixels.transpose(0, 2, 1, 3, 4)  # [grid_y, grid_x, cube_y, cube_x, RGB]
    pixels = pixels.reshape(grid_size * grid_size, cube_size * cube_size, 3)

    # Reshape back to original dimensions
    pixels = pixels.reshape(height, width, 3)

    # Save as a strip LUT
    strip_lut = Image.fromarray(pixels, mode="RGB")
    strip_lut.save(output_path)


def main():
    parser = argparse.ArgumentParser(description="Convert LUT formats")
    parser.add_argument("input", help="Input LUT file (.png or .cube)")
    parser.add_argument("output", help="Output strip LUT file (.png)")
    parser.add_argument(
        "--reference",
        help="Reference LUT file for .cube inputs (default: ReferenceLUT.png in script directory)",
        default=os.path.join(os.path.dirname(__file__), "ReferenceLUT.png"),
    )

    args = parser.parse_args()

    if args.input.lower().endswith(".cube") and not os.path.exists(args.reference):
        parser.error(f"Reference LUT not found: {args.reference}")

    convert_lut(args.input, args.output)


if __name__ == "__main__":
    main()
