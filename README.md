[TermForge](./media/termforge.png)

# TermForge

**TermForge** is a Dockerized terminal recording engine that produces standardized, sterilized GIF recordings for embedding in articles, documentation, and tutorials.

Define your commands in a YAML manifest — TermForge types them out character-by-character in a clean Fish shell with a Starship prompt, captures the output with asciinema, and exports animated GIFs with [agg](https://github.com/asciinema/agg).

---

## Features

- Fish shell + Starship prompt with configurable `user@hostname`
- YAML-driven command manifests
- Character-by-character typing simulation with configurable speed
- Description comments typed before each command for context
- `bat` with auto-scroll pager for file viewing
- Configurable terminal size, theme, and timing
- Pre-built data mounting for scenario recordings
- Docker socket passthrough for Docker-in-Docker commands
- Dual output: `.cast` (asciinema) + `.gif` per command
- Docker-based — amd64 + arm64

---

## Quick Start

### 1. Build

```bash
git clone https://github.com/jknyght9/termforge.git
cd termforge
./build.sh
```

### 2. Create a manifest

```yaml
session:
  hostname: forensics-lab
  username: analyst

commands:
  - name: hello-world
    description: "Test basic output"
    command: "echo 'Hello from TermForge!'"

  - name: system-info
    description: "Show system information"
    command: "uname -a"
```

Save as `commands.yaml`.

### 3. Record

```bash
./record.sh commands.yaml ./output/
```

Output:
```
output/
├── casts/
│   ├── hello-world.cast
│   └── system-info.cast
└── gifs/
    ├── hello-world.gif
    └── system-info.gif
```

Each GIF shows the Starship prompt (`analyst@forensics-lab ~ $`), a `# description` comment typed first, then the command typed and executed.

---

## Manifest Reference

### Session Settings

All session settings are optional and have sensible defaults.

```yaml
session:
  hostname: workstation         # Container hostname (default: workstation)
  username: user                # Prompt username (default: user)
  working_dir: /home/user       # Starting directory (default: user's home)
  packages:                     # apt packages installed at container start
    - sleuthkit
    - xxd
  terminal:
    cols: 120                   # Terminal width (default: 120)
    rows: 30                    # Terminal height (default: 30)
  typing:
    char_delay_ms: 40           # Delay between characters (default: 40)
    pre_enter_ms: 300           # Pause before pressing enter (default: 300)
    post_output_ms: 200         # Pause before output appears (default: 200)
    end_pause_ms: 2000          # Pause at end for reading (default: 2000)
    scroll_delay_ms: 80         # Auto-scroll speed for bat/pager (default: 80)
  gif:
    font_size: 14               # GIF font size in pt (default: 14)
    theme: dracula              # agg color theme (default: dracula)
```

### Commands

```yaml
commands:
  - name: unique-name           # Output filename (required)
    description: "What this does" # Typed as "# comment" before the command
    command: "ls -la"           # The command to type and execute (required)
    setup: |                    # Silent pre-commands (optional, not recorded)
      mkdir -p /tmp/demo
      echo "hello" > /tmp/demo/test.txt
```

- **`name`** drives the output filenames: `<name>.cast` and `<name>.gif`
- **`description`** is typed as a `# comment` line on its own prompt before the actual command, establishing context for the viewer
- **`setup`** runs silently before recording starts — use it for pre-conditions
- Commands share state — files created by one command persist for the next

### Available Themes

`asciinema` | `dracula` | `github-dark` | `github-light` | `gruvbox-dark` | `kanagawa` | `monokai` | `nord` | `solarized-dark` | `solarized-light`

---

## Using `bat` for File Viewing

TermForge includes [bat](https://github.com/sharkdp/bat) as a `cat` replacement with syntax highlighting, line numbers, and grid borders. A custom auto-scroll pager outputs content line-by-line instead of dumping everything at once or waiting for keyboard input.

```yaml
  - name: view-config
    description: "View the configuration file"
    command: "bat config.json"
```

The scroll speed is controlled by `session.typing.scroll_delay_ms` (default: 80ms per line).

For non-bat commands that produce long output, pipe through the auto-scroll pager directly:

```yaml
  - name: hex-dump
    description: "View the first 512 bytes"
    command: "xxd -l 512 disk.img | /app/scripts/auto-scroll.sh"
```

---

## Pre-built Data

For scenarios that require pre-built artifacts (disk images, compiled binaries, test results), use the `--data` flag to mount a host directory into the container:

```bash
./record.sh commands.yaml ./output/ --data /path/to/artifacts
```

Contents of the data directory are copied into the working directory at container start. Commands can then reference the files directly.

---

## Docker Passthrough

For commands that need to run Docker (e.g., building images), pass the `--docker` flag to mount the host Docker socket:

```bash
./record.sh commands.yaml ./output/ --docker
```

**Limitation:** Docker commands that use volume mounts (`-v`) will fail because the paths inside the TermForge container don't exist on the host. For scenarios that need volume mounts, pre-build the artifacts and use `--data` instead.

---

## Project Structure

```
termforge/
├── Dockerfile                  # Ubuntu 24.04 + fish + starship + asciinema + agg
├── build.sh                    # docker build wrapper
├── record.sh                   # docker run wrapper with flag parsing
├── scripts/
│   ├── entrypoint.sh           # Parses YAML manifest, creates user, loops commands
│   ├── record-command.sh       # Records one command (asciinema + agg pipeline)
│   ├── type-and-run.fish       # Typing simulation with starship prompt rendering
│   └── auto-scroll.sh          # Line-by-line pager for bat and piped output
├── config/
│   ├── starship.toml           # Minimal single-line prompt config
│   └── config.fish             # Fish shell greeting and colors
└── examples/
    └── diskforge.yaml          # Example manifest for DiskForge article recordings
```

---

## How It Works

1. **`record.sh`** parses the YAML manifest hostname, resolves paths, and runs the Docker container with appropriate volume mounts
2. **`entrypoint.sh`** creates a user, installs packages, loads pre-built data, and loops over each command in the manifest
3. **`record-command.sh`** writes the command to a temp file, creates a PTY with `script`, and runs `asciinema rec` to capture the session
4. **`type-and-run.fish`** renders the Starship prompt via `starship prompt`, types the description as a `# comment`, types the command character-by-character, executes it, and pauses for the viewer
5. **`agg`** converts the `.cast` recording to an animated `.gif` with the configured theme, font, and dimensions

---

## Requirements

- Docker (Desktop or Engine)
- ~2GB disk space for the Docker image (Rust/agg compilation)

---

## License

This project is open source and distributed under the MIT License.

> This software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and noninfringement. In no event shall the authors be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software.

---

## Author

Created by **Jacob Stauffer** | CISSP, GCFA, GREM, OSCP

Contributions and PRs welcome!

<a href="https://www.buymeacoffee.com/jstauffer" target="_blank"><img src="https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png" alt="Buy Me A Coffee" style="height: 41px !important;width: 174px !important;box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;-webkit-box-shadow: 0px 3px 2px 0px rgba(190, 190, 190, 0.5) !important;" ></a>
