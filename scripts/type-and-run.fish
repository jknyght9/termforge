#!/usr/bin/env fish
# Simulates typing a command character-by-character with starship prompt, then executes it.
# If a description is provided, types it as a "# comment" line first.
# Usage: fish type-and-run.fish <cmd_file> <timing_env_file> [desc_file]

set cmd_file $argv[1]
set timing_file $argv[2]
set desc_file $argv[3]

# Parse timing config
set char_delay_ms 40
set pre_enter_ms 300
set post_output_ms 200
set end_pause_ms 2000
set working_dir ""
set username_val ""

for line in (command cat $timing_file)
    set parts (string split "=" $line)
    switch $parts[1]
        case CHAR_DELAY
            set char_delay_ms $parts[2]
        case PRE_ENTER
            set pre_enter_ms $parts[2]
        case POST_OUTPUT
            set post_output_ms $parts[2]
        case END_PAUSE
            set end_pause_ms $parts[2]
        case WORKING_DIR
            set working_dir $parts[2]
        case USERNAME
            set username_val $parts[2]
    end
end

# Convert ms to seconds for sleep
set char_delay (math "$char_delay_ms / 1000")
set pre_enter (math "$pre_enter_ms / 1000")
set post_output (math "$post_output_ms / 1000")
set end_pause (math "$end_pause_ms / 1000")

# Change to working directory
if test -n "$working_dir"
    cd $working_dir
end

# Read the command and description
set cmd (command cat $cmd_file)
set desc ""
if test -n "$desc_file" -a -f "$desc_file"
    set desc (command cat $desc_file)
end

# Set user identity for starship prompt
if test -n "$username_val"
    set -x USER $username_val
end
set -x STARSHIP_CONFIG /etc/starship.toml
set -x STARSHIP_SHELL fish

# --- Type the description as a comment first (if provided) ---
if test -n "$desc"
    # Render prompt
    printf '%s' (starship prompt --status=0)

    # Type "# <description>"
    set comment "# $desc"
    for i in (seq 1 (string length "$comment"))
        set char (string sub -s $i -l 1 "$comment")
        printf '%s' "$char"
        sleep $char_delay
    end

    # Press enter (comment is a no-op)
    sleep $pre_enter
    echo ""
    sleep $post_output
end

# --- Type and execute the actual command ---
# Render prompt
printf '%s' (starship prompt --status=0)

# Type each character
for i in (seq 1 (string length "$cmd"))
    set char (string sub -s $i -l 1 "$cmd")
    printf '%s' "$char"
    sleep $char_delay
end

# Pause before "pressing enter"
sleep $pre_enter
echo ""

# Brief pause before output appears
sleep $post_output

# Execute the command
eval $cmd

# Pause at end for viewer to read output
sleep $end_pause
