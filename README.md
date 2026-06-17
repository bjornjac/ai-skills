# ai-skills

Reusable Codex and Claude Code skills for AI/tooling host maintenance.

## Install

Unix/Linux/macOS:

```sh
curl -fsSL https://raw.githubusercontent.com/bjornjac/ai-skills/main/install.sh | bash -s --
```

Windows with PowerShell:

```powershell
iwr https://raw.githubusercontent.com/bjornjac/ai-skills/main/install.ps1 -UseBasicParsing | iex; Install-AiSkills
```

Or from a local checkout:

```sh
./install.sh
```

By default, skills are installed into both `${CODEX_HOME:-$HOME/.codex}/skills` for Codex and `${CLAUDE_HOME:-$HOME/.claude}/skills` for Claude Code.

Flags:

- Install into one custom directory with `--dest <path>` or `-Dest <path>`.
- Install only one product with `--target codex|claude|all` or `-Target codex|claude|all`.
- Override product directories with `--codex-dest <path>` / `-CodexDest <path>` and `--claude-dest <path>` / `-ClaudeDest <path>`.
- Install from a pinned release with `--version <version>` or `-Version <version>`.
- Force the latest release with `--latest` or `-Latest`.
- Use another fallback branch with `--ref <ref>` or `-Ref <ref>`.
- Install from another fork with `--repo <url>` or `-Repo <url>`.

The installers default to the latest GitHub release and fall back to the `main` branch archive when no release archive is available.

## Release

After committing changes, create a release tag:

```sh
./.do-release.sh 1.0.0
```

Pushing a `v*.*.*` tag builds `installer.tgz` and `installer.zip` and uploads them to the GitHub release.

## Skills

- `unslop`: clean up AI-generated code while preserving behavior and matching project style.
- `npm-cleanup`: audit and enforce npm/pnpm global package policy, including Linux systemd and Windows Scheduled Task updater templates.
