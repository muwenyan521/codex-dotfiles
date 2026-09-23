#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CONFIG_FILE="$CODEX_HOME/config.toml"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

if ! python3 -c 'import tomllib' >/dev/null 2>&1; then
  printf '%s\n' 'Python 3.11+ is required to merge TOML without overwriting existing settings.' >&2
  exit 1
fi

mkdir -p "$CODEX_HOME"
mkdir -p "$CODEX_HOME/backups"
BACKUP_DIR="$(mktemp -d "$CODEX_HOME/backups/codex-dotfiles-$TIMESTAMP.XXXXXX")"
if [[ -f "$CONFIG_FILE" ]]; then
  cp -p "$CONFIG_FILE" "$BACKUP_DIR/config.toml"
fi

if [[ -f "$CONFIG_FILE" ]] && [[ -d "$CODEX_HOME/plugins/cache/sisyphuslabs/omo" ]] \
  && awk '
    /^\[plugins\."omo@sisyphuslabs"\]$/ { in_plugin = 1; next }
    /^\[/ { in_plugin = 0 }
    in_plugin && /^enabled[[:space:]]*=[[:space:]]*true([[:space:]]*(#.*)?)?$/ { found = 1 }
    END { exit !found }
  ' "$CONFIG_FILE"; then
  printf '%s\n' 'LazyCodex OMO cache and plugin configuration are present; skipping LazyCodex installation.'
else
  if ! command -v npx >/dev/null 2>&1; then
    printf '%s\n' 'npx was not found. Install Node.js/npm, then rerun this script.' >&2
    exit 1
  fi
  printf '%s\n' 'LazyCodex was not detected; installing the Codex edition with npx.'
  npx --yes lazycodex-ai@4.19.4 install --no-tui
fi

python3 - "$CONFIG_FILE" "$REPO_ROOT/config/config.toml" <<'PY'
import re
import sys
import tomllib
from pathlib import Path

target = Path(sys.argv[1])
template = Path(sys.argv[2])
target_text = target.read_text(encoding="utf-8") if target.exists() else ""
template_text = template.read_text(encoding="utf-8")
current = tomllib.loads(target_text)
tomllib.loads(template_text)

def table_at(document, header):
    parsed = tomllib.loads(f"{header}\n__probe = true\n")
    def find_path(node, prefix):
        if "__probe" in node:
            return prefix
        for key, value in node.items():
            if isinstance(value, dict):
                path = find_path(value, [*prefix, key])
                if path is not None:
                    return path
        return None

    path_keys = find_path(parsed, [])
    if path_keys is None:
        return None
    result = document
    for key in path_keys:
        if key not in result or not isinstance(result[key], dict):
            return None
        result = result[key]
    return result

lines = template_text.splitlines(keepends=True)
root_lines: list[str] = []
blocks: list[tuple[str, list[str]]] = []
for line in lines:
    if line.startswith("[") and line.rstrip().endswith("]"):
        blocks.append((line.strip(), [line]))
    elif blocks:
        blocks[-1][1].append(line)
    else:
        root_lines.append(line)

additions: list[str] = []
root_additions: list[str] = []
if root_lines:
    for line in root_lines:
        match = re.match(r"^([A-Za-z0-9_-]+)\s*=", line)
        if match and match.group(1) not in current:
            root_additions.append(line)

for header, block in blocks:
    existing_table = table_at(current, header)
    if existing_table is None:
        additions.extend(block)
        continue

    missing_lines = []
    for line in block[1:]:
        match = re.match(r"^([A-Za-z0-9_-]+)\s*=", line)
        if match and match.group(1) not in existing_table:
            missing_lines.append(line)
    if missing_lines:
        normalized_header = header
        target_lines = target_text.splitlines(keepends=True)
        section_start = next((i for i, line in enumerate(target_lines) if line.strip() == normalized_header), None)
        if section_start is None:
            additions.extend(block)
            continue
        section_end = next((i for i in range(section_start + 1, len(target_lines)) if target_lines[i].lstrip().startswith("[")), len(target_lines))
        target_lines[section_end:section_end] = missing_lines
        target_text = "".join(target_lines)
        current = tomllib.loads(target_text)

if additions or root_additions:
    merged = "".join(root_additions)
    if merged and target_text:
        merged += "\n"
    merged += target_text.rstrip()
    if merged:
        merged += "\n\n"
    merged += "".join(additions).lstrip("\n")
    tomllib.loads(merged)
    target.write_text(merged.rstrip() + "\n", encoding="utf-8")
PY

install_managed_file() {
  local source="$1" relative="$2" destination_root="${3:-$CODEX_HOME}"
  local destination="$destination_root/$relative"
  mkdir -p "$(dirname -- "$destination")"
  if [[ -e "$destination" ]]; then
    local backup_relative="$relative"
    if [[ "$destination_root" != "$CODEX_HOME" ]]; then
      backup_relative="user-skills/$relative"
    fi
    mkdir -p "$BACKUP_DIR/$(dirname -- "$backup_relative")"
    cp -a "$destination" "$BACKUP_DIR/$backup_relative"
  fi
  cp -a "$source" "$destination"
}

while IFS= read -r -d '' source; do
  relative="${source#"$REPO_ROOT/"}"
  install_managed_file "$source" "$relative"
done < <(find "$REPO_ROOT/agents" -type f -print0)

while IFS= read -r -d '' source; do
  relative="${source#"$REPO_ROOT/skills/"}"
  install_managed_file "$source" "$relative" "$HOME/.agents/skills"
done < <(find "$REPO_ROOT/skills" -type f -print0)

install_managed_file "$REPO_ROOT/prompts/codex-global.md" "prompts/codex-global.md"
install_managed_file "$REPO_ROOT/AGENTS.md" "AGENTS.md"

printf 'Installed Codex dotfiles into %s\n' "$CODEX_HOME"
printf 'Backup: %s\n' "$BACKUP_DIR"
printf '%s\n' 'Restart Codex TUI/Desktop to reload global prompt, plugins, agents, and skills.'
