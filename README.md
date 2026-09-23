# Codex Dotfiles

Portable Codex settings, prompt, agents, and personal skills for Codex CLI/TUI and Codex in the ChatGPT desktop app. Both local clients use the user-level Codex configuration (`~/.codex/config.toml` by default); the documented user skill directory `$HOME/.agents/skills` is shared by ChatGPT and Codex.

The `[tui]` section below only controls TUI presentation. Desktop-specific window and panel preferences remain owned by the desktop app; the shared model, prompt, plugin, agent, and skill setup applies to both local Codex surfaces.

This split follows the [Codex configuration reference](https://developers.openai.com/codex/config-reference/) and [skills documentation](https://developers.openai.com/codex/skills/): user-level config lives in `~/.codex/config.toml`, and `$HOME/.agents/skills` is the user-scope skill directory shared by ChatGPT and Codex. The desktop app itself is not installed or driven by this repository's installer.

This repository intentionally does not contain `auth.json`, MCP credentials, provider keys, history, session databases, local MCP executable paths, plugin caches, or machine backups. Provider/model selection and authentication stay on the target machine.

## Install

Requirements: Codex CLI, Git, Node.js/npm (only when LazyCodex is missing), Bash, and Python 3.11+.

Clone this repository, inspect `scripts/install.sh`, then run it from Bash on macOS/Linux or Git Bash/WSL on Windows:

```sh
git clone https://github.com/muwenyan521/codex-dotfiles.git
cd codex-dotfiles
bash scripts/install.sh
```

The installer detects an existing LazyCodex OMO cache and enabled config entry. If either is missing, it runs `npx --yes lazycodex-ai@4.19.4 install --no-tui`. It backs up `config.toml` before calling LazyCodex, then merges only missing TOML settings. It preserves existing provider, model, auth, and other Codex settings. Agents and the global prompt go to `CODEX_HOME`; skills go to `$HOME/.agents/skills` so both ChatGPT and Codex discover the same user skills. Backups are stored under `$CODEX_HOME/backups/codex-dotfiles-TIMESTAMP.RANDOM/` (normally `~/.codex/backups/`).

Review the merged `~/.codex/config.toml` and restart Codex TUI/Desktop. If the existing config already defines `model_instructions_file` or any of these tables, the installer deliberately leaves those existing values intact.

Rollback: restore the backed-up `config.toml`, `AGENTS.md`, prompt, agents, or `user-skills/` files from the printed backup directory. Files that did not previously exist can be removed from `CODEX_HOME` or `$HOME/.agents/skills` if you want to fully undo the installation.

To use a non-default Codex home, set `CODEX_HOME` for the install command:

```sh
CODEX_HOME="$HOME/.codex-test" bash scripts/install.sh
```

## Prompt for an AI Installer

Copy this prompt into Codex, ChatGPT, or another coding agent on the target machine:

> Install this Codex dotfiles repository on this machine. First inspect the repository instructions and `scripts/install.sh`, explain what it will change, and check that `CODEX_HOME` is the directory used by my Codex CLI/TUI and Desktop. Preserve my existing provider, model, authentication, MCP credentials, and unrelated files. Run the installer only after confirming its backup and merge behavior. It should install LazyCodex automatically only if the Codex OMO plugin is not already installed. Do not expose credentials or print their values. After installation, validate the resulting TOML, check that the global prompt, agents, skills, and OMO plugin files are present, and tell me exactly which restart or manual step remains.

## Contents

- `config/config.toml`: portable Codex preferences and OMO plugin registration.
- `prompts/codex-global.md`: global collaboration prompt with personal identifiers removed.
- `agents/`: agent role definitions; their model fields use the configured Codex model catalog and may need adjustment on a target account with a different catalog. The main config does not force a provider/model.
- `skills/`: user-level skills installed into `$HOME/.agents/skills`, shared by ChatGPT and Codex. System-managed skills and plugin caches are excluded.
- `AGENTS.md`: global project/workspace instructions.
- `scripts/install.sh`: backup-first installer shared by TUI and Desktop.

## Customization

Edit the files in this repository, review the diff for personal data and machine-specific paths, then rerun the installer. Existing TOML values win; edit them manually when you intentionally want to replace a target-machine setting.
