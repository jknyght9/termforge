#!/bin/bash
# Record a single command with typing simulation using fish + starship
# Usage: record-command.sh <output-name> <command> [description]
#
# Expects environment variables from entrypoint.sh:
#   COLS, ROWS, CHAR_DELAY, PRE_ENTER, POST_OUTPUT, END_PAUSE,
#   FONT_SIZE, THEME, USERNAME_VAL, WORKING_DIR

OUTPUT_NAME="$1"
COMMAND="$2"
DESCRIPTION="$3"

CAST_FILE="/output/casts/${OUTPUT_NAME}.cast"
GIF_FILE="/output/gifs/${OUTPUT_NAME}.gif"
CMD_FILE="/tmp/${OUTPUT_NAME}_cmd.txt"
DESC_FILE="/tmp/${OUTPUT_NAME}_desc.txt"
TIMING_FILE="/tmp/${OUTPUT_NAME}_timing.env"
SIM_SCRIPT="/tmp/${OUTPUT_NAME}_sim.sh"

mkdir -p /output/gifs /output/casts

# Write command to file to avoid quoting issues
printf '%s' "$COMMAND" > "$CMD_FILE"

# Write description to file (empty if none)
if [ -n "$DESCRIPTION" ] && [ "$DESCRIPTION" != "null" ]; then
    printf '%s' "$DESCRIPTION" > "$DESC_FILE"
else
    printf '' > "$DESC_FILE"
fi

# Write timing config for the fish script
cat > "$TIMING_FILE" << EOF
CHAR_DELAY=$CHAR_DELAY
PRE_ENTER=$PRE_ENTER
POST_OUTPUT=$POST_OUTPUT
END_PAUSE=$END_PAUSE
WORKING_DIR=$WORKING_DIR
USERNAME=$USERNAME_VAL
EOF

# Create wrapper script that runs inside the script PTY
cat > "$SIM_SCRIPT" << WRAPPER
#!/bin/bash
stty cols $COLS rows $ROWS 2>/dev/null
export COLUMNS=$COLS LINES=$ROWS TERM=xterm-256color
export STARSHIP_CONFIG=/etc/starship.toml
export USER=$USERNAME_VAL HOME=/home/$USERNAME_VAL
export SCROLL_DELAY=\$(echo "scale=3; $SCROLL_DELAY / 1000" | bc)
export HOSTNAME=\$(hostname)
cd $WORKING_DIR
asciinema rec --overwrite -q \
    -c "fish /app/scripts/type-and-run.fish $CMD_FILE $TIMING_FILE $DESC_FILE" \
    $CAST_FILE
WRAPPER
chmod +x "$SIM_SCRIPT"

# Record using script to provide a PTY
{
    script -q -c "$SIM_SCRIPT" /dev/null
} > /dev/null 2>&1

# Convert to GIF with agg (theme is configurable via YAML)
if [ -f "$CAST_FILE" ]; then
    agg \
        --font-size "$FONT_SIZE" \
        --cols "$COLS" \
        --rows "$ROWS" \
        --font-family "JetBrains Mono,DejaVu Sans Mono,monospace" \
        --idle-time-limit 3 \
        --theme "${THEME:-dracula}" \
        "$CAST_FILE" "$GIF_FILE" > /dev/null 2>&1
else
    echo "WARNING: Cast file not created for ${OUTPUT_NAME}" >&2
fi

# Cleanup temp files
rm -f "$CMD_FILE" "$DESC_FILE" "$TIMING_FILE" "$SIM_SCRIPT"

echo "${OUTPUT_NAME}"
