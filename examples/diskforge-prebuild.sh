#!/bin/bash
# Pre-builds DiskForge artifacts for termforge recordings.
# Run this BEFORE running the termforge recording.
#
# Usage: bash examples/diskforge-prebuild.sh

set -e

PREBUILD_DIR="$(pwd)/prebuild-diskforge"
echo "=== DiskForge Pre-build ==="
echo "Working directory: $PREBUILD_DIR"
echo ""

# Clone
if [ ! -d "$PREBUILD_DIR/diskforge" ]; then
    echo "[1/4] Cloning DiskForge..."
    mkdir -p "$PREBUILD_DIR"
    git clone https://github.com/jknyght9/diskforge.git "$PREBUILD_DIR/diskforge"
else
    echo "[1/4] DiskForge already cloned"
fi

# Build Docker image
echo "[2/4] Building DiskForge Docker image..."
cd "$PREBUILD_DIR/diskforge"
docker build -q -t diskforge .

# Build each example image individually and preserve it
# DiskForge removes old images when building new ones in the same dir,
# so we build each into a temp dir and copy the output to a shared dir.
echo "[3/4] Building all example disk images..."
mkdir -p "$PREBUILD_DIR/output"

for example_dir in examples/example_*/; do
    example_name=$(basename "$example_dir")
    tmp_output="$PREBUILD_DIR/tmp_${example_name}"
    mkdir -p "$tmp_output"

    echo "  Building: $example_name"
    docker run --rm --privileged \
        -v "$(pwd)/${example_dir}manifest.json:/manifests/manifest.json" \
        -v "$(pwd)/files:/files" \
        -v "$tmp_output:/output" \
        diskforge /manifests/manifest.json 2>&1 | tail -1

    # Copy built image(s) to shared output dir
    cp "$tmp_output"/*.img "$PREBUILD_DIR/output/" 2>/dev/null || true
    rm -rf "$tmp_output"
done

# Run tests and capture output
echo "[4/4] Running test suite..."
bash test/test.sh > "$PREBUILD_DIR/test-results.txt" 2>&1 || true

echo ""
echo "=== Pre-build Complete ==="
echo "Artifacts:"
ls -lh "$PREBUILD_DIR/output/"
echo ""
echo "Test results: $PREBUILD_DIR/test-results.txt"
echo ""
echo "Next step:"
echo "  ./record.sh examples/diskforge.yaml ../diskforge/assets/recordings/ --data prebuild-diskforge"
