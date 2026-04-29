#!/bin/bash
set -e

MANIFEST="${1:?Usage: record.sh <commands.yaml> [output-dir] [--docker] [--data /path/to/dir]}"
OUTPUT_DIR="${2:-./output}"

# Parse flags
DOCKER_FLAG=""
DATA_DIR=""
ARGS=("$@")
for i in "${!ARGS[@]}"; do
    if [ "${ARGS[$i]}" = "--docker" ]; then
        DOCKER_FLAG="yes"
    elif [ "${ARGS[$i]}" = "--data" ]; then
        DATA_DIR="${ARGS[$((i+1))]}"
    fi
done

# Resolve to absolute paths
MANIFEST="$(cd "$(dirname "$MANIFEST")" && pwd)/$(basename "$MANIFEST")"
OUTPUT_DIR="$(mkdir -p "$OUTPUT_DIR" && cd "$OUTPUT_DIR" && pwd)"

# Parse hostname from YAML for docker --hostname
# Try yq first, then python+pyyaml, then grep fallback
HOSTNAME_VAL="workstation"
if command -v yq &> /dev/null; then
    HOSTNAME_VAL=$(yq '.session.hostname // "workstation"' "$MANIFEST")
elif command -v python3 &> /dev/null && python3 -c "import yaml" 2>/dev/null; then
    HOSTNAME_VAL=$(python3 -c "
import yaml
with open('$MANIFEST') as f:
    d = yaml.safe_load(f)
print(d.get('session', {}).get('hostname', 'workstation'))
" 2>/dev/null || echo "workstation")
else
    # Grep fallback: find "hostname:" line under session
    PARSED=$(grep -A1 'session:' "$MANIFEST" 2>/dev/null | grep 'hostname:' | head -1 | sed 's/.*hostname:[[:space:]]*//' | tr -d '"'"'" 2>/dev/null)
    if [ -z "$PARSED" ]; then
        PARSED=$(grep 'hostname:' "$MANIFEST" 2>/dev/null | head -1 | sed 's/.*hostname:[[:space:]]*//' | tr -d '"'"'" 2>/dev/null)
    fi
    [ -n "$PARSED" ] && HOSTNAME_VAL="$PARSED"
fi

echo "=== Termforge ==="
echo "Manifest: $MANIFEST"
echo "Output:   $OUTPUT_DIR"
echo "Host:     $HOSTNAME_VAL"
echo ""

EXTRA_ARGS=""
if [ "$DOCKER_FLAG" = "yes" ]; then
    echo "Docker: socket passthrough enabled"
    EXTRA_ARGS="$EXTRA_ARGS -v /var/run/docker.sock:/var/run/docker.sock"
fi
if [ -n "$DATA_DIR" ]; then
    DATA_DIR="$(cd "$DATA_DIR" && pwd)"
    echo "Data:   $DATA_DIR -> /data"
    EXTRA_ARGS="$EXTRA_ARGS -v $DATA_DIR:/data:ro"
fi
echo ""

docker run --rm \
    --hostname "$HOSTNAME_VAL" \
    -v "$MANIFEST:/input/commands.yaml:ro" \
    -v "$OUTPUT_DIR:/output" \
    $EXTRA_ARGS \
    termforge
