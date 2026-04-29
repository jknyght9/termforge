#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Building termforge image..."
docker build -t termforge .

echo ""
echo "Built termforge image successfully."
echo "Usage: ./record.sh /path/to/commands.yaml [output-dir]"
