#!/bin/bash
# Auto-scrolling pager for bat. Reads stdin and outputs line by line
# with a delay, simulating someone scrolling through a file.
# Used as BAT_PAGER to replace less in non-interactive recordings.

SCROLL_DELAY="${SCROLL_DELAY:-0.08}"

while IFS= read -r line; do
    printf '%s\n' "$line"
    sleep "$SCROLL_DELAY"
done
