# Termforge Fish Configuration

# Disable greeting
set -g fish_greeting ""

# Initialize starship
starship init fish | source

# Clean syntax highlighting colors for recordings
set -g fish_color_command green
set -g fish_color_param normal
set -g fish_color_error red
set -g fish_color_quote yellow
set -g fish_color_operator cyan
