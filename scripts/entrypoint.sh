#!/bin/bash
set -e

MANIFEST="/input/commands.yaml"

if [ ! -f "$MANIFEST" ]; then
    echo "ERROR: No manifest found at $MANIFEST"
    echo "Mount your commands YAML file: -v /path/to/commands.yaml:/input/commands.yaml"
    exit 1
fi

# Parse session settings with defaults
HOSTNAME_VAL=$(yq '.session.hostname // "workstation"' "$MANIFEST")
USERNAME_VAL=$(yq '.session.username // "user"' "$MANIFEST")
WORKING_DIR=$(yq '.session.working_dir // ""' "$MANIFEST")
COLS=$(yq '.session.terminal.cols // 120' "$MANIFEST")
ROWS=$(yq '.session.terminal.rows // 30' "$MANIFEST")
CHAR_DELAY=$(yq '.session.typing.char_delay_ms // 40' "$MANIFEST")
PRE_ENTER=$(yq '.session.typing.pre_enter_ms // 300' "$MANIFEST")
POST_OUTPUT=$(yq '.session.typing.post_output_ms // 200' "$MANIFEST")
END_PAUSE=$(yq '.session.typing.end_pause_ms // 2000' "$MANIFEST")
SCROLL_DELAY=$(yq '.session.typing.scroll_delay_ms // 80' "$MANIFEST")
FONT_SIZE=$(yq '.session.gif.font_size // 14' "$MANIFEST")
THEME=$(yq '.session.gif.theme // "dracula"' "$MANIFEST")

# Default working_dir to user's home if not set
if [ -z "$WORKING_DIR" ] || [ "$WORKING_DIR" = "null" ]; then
    WORKING_DIR="/home/$USERNAME_VAL"
fi

# Hostname is set via docker run --hostname; update /etc/hostname for consistency
echo "$HOSTNAME_VAL" > /etc/hostname 2>/dev/null || true

# Create user with fish shell
useradd -m -s /usr/bin/fish "$USERNAME_VAL" 2>/dev/null || true

# Set up fish + starship config for user
USER_HOME="/home/$USERNAME_VAL"
mkdir -p "$USER_HOME/.config/fish/conf.d"
cp /etc/fish/conf.d/termforge.fish "$USER_HOME/.config/fish/conf.d/"

# Ensure starship config is accessible
echo "export STARSHIP_CONFIG=/etc/starship.toml" >> "$USER_HOME/.bashrc"

# Create working directory if needed
mkdir -p "$WORKING_DIR"
chown -R "$USERNAME_VAL:$USERNAME_VAL" "$USER_HOME"
chown "$USERNAME_VAL:$USERNAME_VAL" "$WORKING_DIR" 2>/dev/null || true

# Copy pre-built data into working directory if /data is mounted
if [ -d "/data" ] && [ "$(ls -A /data 2>/dev/null)" ]; then
    echo "Loading pre-built data from /data..."
    cp -r /data/* "$WORKING_DIR/" 2>/dev/null || true
fi

# Install packages if specified
PKG_COUNT=$(yq '.session.packages | length // 0' "$MANIFEST")
if [ "$PKG_COUNT" -gt 0 ]; then
    PACKAGES=$(yq '.session.packages[]' "$MANIFEST" | tr '\n' ' ')
    echo "Installing packages: $PACKAGES"
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq $PACKAGES > /dev/null 2>&1
fi

# Export settings for record-command.sh
export COLS ROWS CHAR_DELAY PRE_ENTER POST_OUTPUT END_PAUSE SCROLL_DELAY FONT_SIZE THEME USERNAME_VAL WORKING_DIR

# Create output directories
mkdir -p /output/casts /output/gifs

# Count commands
CMD_COUNT=$(yq '.commands | length' "$MANIFEST")

echo "=== Termforge Recording Engine ==="
echo "Recording $CMD_COUNT command(s) as $USERNAME_VAL@$HOSTNAME_VAL"
echo "Terminal: ${COLS}x${ROWS} | Typing: ${CHAR_DELAY}ms/char"
echo ""

# Process each command
for i in $(seq 0 $((CMD_COUNT - 1))); do
    CMD_NAME=$(yq ".commands[$i].name" "$MANIFEST")
    CMD_TEXT=$(yq ".commands[$i].command" "$MANIFEST")
    CMD_SETUP=$(yq ".commands[$i].setup // \"\"" "$MANIFEST")
    CMD_DESC=$(yq ".commands[$i].description // \"\"" "$MANIFEST")

    echo "[$((i+1))/$CMD_COUNT] Recording: $CMD_NAME"
    [ -n "$CMD_DESC" ] && [ "$CMD_DESC" != "null" ] && echo "         $CMD_DESC"

    # Run setup commands silently in the same context as the recording
    if [ -n "$CMD_SETUP" ] && [ "$CMD_SETUP" != "" ] && [ "$CMD_SETUP" != "null" ]; then
        (cd "$WORKING_DIR" && bash -c "$CMD_SETUP") > /dev/null 2>&1 || true
    fi

    # Record the command (pass description for comment line)
    /app/scripts/record-command.sh "$CMD_NAME" "$CMD_TEXT" "$CMD_DESC"
    echo "         -> /output/gifs/${CMD_NAME}.gif"
done

echo ""
echo "=== Complete ==="
echo "Output:"
ls -lh /output/gifs/
