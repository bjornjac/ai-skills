---
name: npm-cleanup
description: Audit and clean npm/pnpm global package state on Linux, Unix-like, and Windows hosts. Use when Codex needs to enforce that admin/root-owned global npm installs are limited to approved CLI packages, Node/npm/pnpm global assets live under /usr/local on Unix-like hosts, random npm/pnpm-installed shims, bins, links, and node_modules under /usr/bin, /usr/lib, /usr/share, or other non-/usr/local locations are removed, pnpm has no user-global installs, pnpm global state uses one admin/root-owned repository, updater units or scheduled tasks follow the same policy, and project directories keep using their own package managers and local dependencies.
---

# NPM Cleanup

Use this skill to audit and remediate global Node package-manager state without disturbing project-local dependencies.

## Policy

Only these tools may be installed globally, and they must be installed by `npm`, not `pnpm`:

- `npm`
- `pnpm`
- `@openai/codex` for the `codex` command
- `@anthropic-ai/claude-code` for the `claude` command
- `@technomoron/agent-run` for the `agent-run` command
- `corepack`, if this host uses Corepack shims
- `fallow`
- `ripgrep` for the `rg`/`ripgrep` commands
- `pm2`
- `tsx`
- `typescript` for the `tsc` command

Treat `pnmp` in user requests as a likely typo for `pnpm` unless the repository or host has a real package named `pnmp`.

Global installs are host tooling only. Do not remove or rewrite project-local `node_modules`, lockfiles, `package.json`, package-manager fields, or workspace configuration unless the user explicitly asks for project cleanup. Projects should continue to use their preferred package manager and their own local dependencies.

On Linux and Unix-like hosts, `/usr/local` is the only approved root for globally managed Node tooling. Approved command shims should resolve from `/usr/local/bin`, npm global packages from `/usr/local/lib/node_modules`, and pnpm global state from `/usr/local/share/pnpm`. Treat npm, pnpm, corepack, random npm/pnpm-installed shims, bins, links, and global `node_modules` under `/usr/bin`, `/usr/lib`, `/usr/lib/node_modules`, `/usr/share/nodejs`, `/usr/share/npm`, `/usr/share/pnpm`, `/opt`, or user-local global directories as stale or noncompliant unless the user explicitly asks to keep a distro-managed Node runtime. The cleanup target is that global package-manager assets and AI/tooling CLIs are consolidated under `/usr/local/*`.

## Root-Only Globals

Require global package-manager commands to run as root:

```sh
test "$(id -u)" -eq 0
```

For `npm`, the global prefix should be a root-owned system prefix such as `/usr/local`, with commands installed into `/usr/local/bin`:

```sh
npm prefix -g
npm root -g
npm config get prefix
for name in node npm npx corepack pnpm; do command -v "$name" 2>/dev/null || true; done
test "$(npm prefix -g)/bin" = /usr/local/bin
test "$(npm root -g)" = /usr/local/lib/node_modules
stat -Lc '%U:%G %a %n' "$(npm prefix -g)" "$(npm root -g)" "$(npm prefix -g)/bin"
```

For `pnpm`, `-g` is allowed only as root, and there must be a single root-owned global package repository. The pnpm global bin directory must also be `/usr/local/bin`, matching npm. Prefer explicit system locations such as:

```sh
pnpm config set --global global-dir /usr/local/share/pnpm/global
pnpm config set --global global-bin-dir /usr/local/bin
install -d -o root -g root -m 0755 /usr/local/share/pnpm/global /usr/local/bin
```

If non-root users resolve different pnpm global paths, put the same defaults in `/etc/npmrc`:

```ini
global-dir=/usr/local/share/pnpm/global
global-bin-dir=/usr/local/bin
```

Also set `PNPM_HOME=/usr/local` system-wide, for example in `/etc/environment`, so pnpm's fallback global bin path resolves to `/usr/local/bin` instead of a user-local pnpm directory:

```ini
PNPM_HOME=/usr/local
```

No user-global pnpm locations should be active. Check at least:

```sh
pnpm config get global-dir
pnpm config get global-bin-dir
pnpm root -g
pnpm bin -g
find /root "$HOME" -maxdepth 4 \( -path '*/.local/share/pnpm' -o -path '*/.pnpm-global' -o -path '*/pnpm/global' \) -type d 2>/dev/null
```

Ignore package-manager caches when deciding global compliance. Caches like `~/.npm`, `~/.cache/pnpm`, and pnpm metadata stores are not global package installs. Never print raw auth tokens from `.npmrc`, pnpm config, environment variables, or logs.

The pnpm package repository may live directly at `/usr/local/share/pnpm/global`, or `/usr/local/share/pnpm` may be a symlink to another storage location for disk space. When a global directory is a symlink, check the symlink target with `stat -L`; symlink mode bits commonly display as `777` and do not grant write access to the target.

## Audit

Inventory npm globals:

```sh
npm list -g --depth=0 --json
ls -la "$(npm root -g)"
ls -la "$(npm prefix -g)/bin" | grep -E 'npm|pnpm|codex|claude|agent-run|corepack|fallow|rg|ripgrep|pm2|tsx|tsc'
for name in node npm npx pnpm pnpx corepack codex claude agent-run fallow rg ripgrep pm2 pm2-dev pm2-runtime tsx tsc; do command -v "$name" 2>/dev/null || true; done
```

Normalize the allowlist to package names before comparing:

```text
npm
pnpm
@openai/codex
@anthropic-ai/claude-code
@technomoron/agent-run
corepack
fallow
ripgrep
pm2
tsx
typescript
```

Inventory pnpm globals:

```sh
pnpm list -g --depth 0 --json
test "$(pnpm bin -g)" = /usr/local/bin
find /usr/local/share/pnpm -maxdepth 4 -type f -o -type l 2>/dev/null
```

Inventory non-`/usr/local` Node assets that should be deleted or explained. This includes known host-tool commands and arbitrary npm/pnpm-created shims or symlinks in `/usr/bin` and related bin directories:

```sh
find /usr/bin /usr/sbin /bin /sbin -maxdepth 1 \( -type f -o -type l \) \
  \( -name node -o -name npm -o -name npx -o -name pnpm -o -name pnpx -o -name corepack -o -name codex -o -name claude -o -name agent-run -o -name fallow -o -name rg -o -name ripgrep -o -name pm2 -o -name 'pm2-*' -o -name tsx -o -name tsc \) -print 2>/dev/null
find /usr/bin /usr/sbin /bin /sbin -maxdepth 1 -type l -exec sh -c 'for p do t=$(readlink "$p" 2>/dev/null || true); case "$t" in *node_modules*|*npm*|*pnpm*|*corepack*) printf "%s -> %s\n" "$p" "$t";; esac; done' sh {} + 2>/dev/null
find /usr/bin /usr/sbin /bin /sbin -maxdepth 1 -type f -exec sh -c 'for p do head -n 1 "$p" 2>/dev/null | grep -Eq "node|npm|pnpm|node_modules" && printf "%s\n" "$p"; done' sh {} + 2>/dev/null
find /usr/lib /usr/share /opt -maxdepth 4 \( -type d -o -type l \) \
  \( -path '*/node_modules' -o -path '*/node_modules/*' -o -path '*/npm' -o -path '*/pnpm' -o -path '*/corepack' -o -path '*/@openai/codex' -o -path '*/@anthropic-ai/claude-code' -o -path '*/@technomoron/agent-run' \) -print 2>/dev/null
```

The compliant result is:

- `npm list -g --depth=0` contains only the allowlisted packages.
- `pnpm list -g --depth 0` is empty or reports no globally installed packages.
- npm and pnpm both resolve global bins to `/usr/local/bin`.
- globally managed Node/npm/pnpm/corepack assets, random npm/pnpm-installed shims, bins, links, and global `node_modules` live under `/usr/local/*`, not `/usr/bin`, `/usr/lib`, `/usr/share`, `/opt`, or user-local global paths.
- pnpm global directories are root-owned and not group/world-writable.
- npm global prefix/root are root-owned and not group/world-writable.
- user-global pnpm/npm directories are absent or unused.
- project-local dependencies are left untouched.

## Remediation

Remove disallowed npm globals by package name:

```sh
npm uninstall -g <disallowed-package>
```

Remove all pnpm global packages. Use exact package names from `pnpm list -g --depth 0`:

```sh
pnpm remove -g <package>
```

Remove stale non-`/usr/local` Node assets after confirming they are command shims, symlinks into npm/pnpm state, package-manager global directories, or obsolete package-manager assets. This includes random executables left by `npm install -g` or `pnpm add -g`, not only the approved tool names. Use package-manager uninstall commands first when an OS package manager owns the files; otherwise delete the stale paths directly. Do not touch project-local dependencies.

```sh
rm -f /usr/bin/npm /usr/bin/npx /usr/bin/pnpm /usr/bin/pnpx /usr/bin/corepack
rm -f /usr/bin/codex /usr/bin/claude /usr/bin/agent-run /usr/bin/fallow /usr/bin/rg /usr/bin/ripgrep /usr/bin/pm2 /usr/bin/pm2-dev /usr/bin/pm2-runtime /usr/bin/tsx /usr/bin/tsc
find /usr/bin /usr/sbin /bin /sbin -maxdepth 1 -type l -exec sh -c 'for p do t=$(readlink "$p" 2>/dev/null || true); case "$t" in *node_modules*|*npm*|*pnpm*|*corepack*) rm -f "$p";; esac; done' sh {} + 2>/dev/null
rm -rf /usr/lib/node_modules /usr/lib/npm /usr/lib/pnpm /usr/lib/corepack
rm -rf /usr/share/nodejs/npm /usr/share/nodejs/pnpm /usr/share/nodejs/corepack /usr/share/npm /usr/share/pnpm
```

If a stale `/usr/bin/node` shadows the intended `/usr/local/bin/node`, remove it only after installing or confirming a working `/usr/local/bin/node` and confirming the user wants Node itself managed from `/usr/local`:

```sh
test -x /usr/local/bin/node
rm -f /usr/bin/node
```

Remove stale pnpm global command shims only after confirming the target package has been removed. If pnpm previously used a separate bin home, remove stale files there. If stale shims are in `/usr/local/bin`, remove only links that point into pnpm global state; do not blindly delete npm-managed commands from `/usr/local/bin`.

```sh
rm -f /usr/local/share/pnpm/bin/<command>
readlink /usr/local/bin/<command> | grep -q '/usr/local/share/pnpm/' && rm -f /usr/local/bin/<command>
```

Install or update approved host tooling with npm:

```sh
npm install -g --force npm@latest pnpm@latest corepack@latest @openai/codex@latest @anthropic-ai/claude-code@latest @technomoron/agent-run@latest fallow@latest ripgrep@latest pm2@latest tsx@latest typescript@latest
```

Re-check command ownership and resolution after cleanup:

```sh
command -v npm pnpm corepack codex claude agent-run fallow rg pm2 tsx tsc
npm list -g --depth=0 --json
pnpm list -g --depth 0 --json
```

## Systemd Updaters

Systemd updater units that maintain these tools must enforce the same policy:

- run as root with `HOME=/root`
- set pnpm global package repository to the single root-owned pnpm home
- set pnpm global bin directory to `/usr/local/bin`
- remove pnpm global installs and stale pnpm shims for the host tools
- install or update the approved tool packages with `npm install -g`
- not install packages outside the npm global allowlist
- not run `pnpm add -g` or `pnpm install -g` for these tools

Audit likely units with:

```sh
systemctl list-timers --all --no-pager | grep -Ei 'update|npm|pnpm|node|codex|claude|agent-run|corepack|fallow|pm2|tsx|tsc'
systemctl list-unit-files --no-pager | grep -Ei 'update|npm|pnpm|node|codex|claude|agent-run|corepack|fallow|pm2|tsx|tsc'
systemctl cat <unit>.service
systemctl cat <unit>.timer
```

If an updater installs non-allowlisted npm globals, remove them from `ExecStart` and uninstall them globally. If an updater installs or references Node package-manager assets, random npm/pnpm shims, bins, links, or `node_modules` under `/usr/bin`, `/usr/lib`, `/usr/share`, `/opt`, or user-local paths, change it to use `/usr/local/bin`, `/usr/local/lib/node_modules`, and `/usr/local/share/pnpm`, then delete the stale non-`/usr/local` assets. If an updater leaves pnpm global directories writable by non-root users, fix ownership and permissions before restarting the timer:

```sh
chown -R root:root /usr/local/share/pnpm /usr/local/lib/node_modules
chmod 0755 /usr/local/share/pnpm /usr/local/share/pnpm/global /usr/local/bin /usr/local/lib/node_modules
stat -Lc '%U:%G %a %n' /usr/local/share/pnpm /usr/local/share/pnpm/global /usr/local/bin /usr/local/lib/node_modules
systemctl daemon-reload
systemctl restart <unit>.timer
```

## Create Updaters

When the user asks to create the updater, generate a platform-native updater that applies the policy above. Do not create project-local scripts for this; this is host tooling.

### Linux or Unix with systemd

Use systemd only on hosts that actually have systemd. Create `/etc/systemd/system/ai-tools-update.service`:

```ini
[Unit]
Description=Update global AI CLI and package-manager tools
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
KillMode=process
Environment=HOME=/root
Environment=XDG_CONFIG_HOME=/root/.config
Environment=PNPM_HOME=/usr/local
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ExecStartPre=/usr/bin/install -d -o root -g root -m 0755 /usr/local/share/pnpm /usr/local/share/pnpm/global /usr/local/bin /usr/local/lib/node_modules
ExecStartPre=/bin/sh -c 'printf "%s\n" "PNPM_HOME=/usr/local" > /etc/environment'
ExecStartPre=/bin/sh -c 'printf "%s\n%s\n" "global-dir=/usr/local/share/pnpm/global" "global-bin-dir=/usr/local/bin" > /etc/npmrc'
ExecStartPre=/bin/sh -c 'chown -R root:root /usr/local/share/pnpm /usr/local/lib/node_modules; chmod 0755 /usr/local/share/pnpm /usr/local/share/pnpm/global /usr/local/bin /usr/local/lib/node_modules'
ExecStartPre=-/bin/sh -c 'rm -f /usr/bin/npm /usr/bin/npx /usr/bin/pnpm /usr/bin/pnpx /usr/bin/corepack /usr/bin/codex /usr/bin/claude /usr/bin/agent-run /usr/bin/fallow /usr/bin/rg /usr/bin/ripgrep /usr/bin/pm2 /usr/bin/pm2-dev /usr/bin/pm2-runtime /usr/bin/tsx /usr/bin/tsc; find /usr/bin /usr/sbin /bin /sbin -maxdepth 1 -type l -exec sh -c '"'"'for p do t=$(readlink "$p" 2>/dev/null || true); case "$t" in *node_modules*|*npm*|*pnpm*|*corepack*) rm -f "$p";; esac; done'"'"' sh {} + 2>/dev/null; if test -x /usr/local/bin/node; then rm -f /usr/bin/node; fi; rm -rf /usr/lib/node_modules /usr/lib/npm /usr/lib/pnpm /usr/lib/corepack /usr/share/nodejs/npm /usr/share/nodejs/pnpm /usr/share/nodejs/corepack /usr/share/npm /usr/share/pnpm'
ExecStartPre=/usr/local/bin/npm install -g --force npm@latest pnpm@latest corepack@latest
ExecStartPre=-/bin/sh -c 'for name in npm npx pnpm pnpx corepack fallow fallow-lsp fallow-mcp codex claude agent-run rg ripgrep pm2 pm2-dev pm2-docker pm2-runtime tsx tsc; do rm -f "/usr/local/share/pnpm/bin/$name"; done; rm -rf /usr/local/share/pnpm/.tools/pnpm'
ExecStartPre=-/bin/sh -c 'if command -v pnpm >/dev/null 2>&1; then pnpm config set --global global-dir /usr/local/share/pnpm/global; pnpm config set --global global-bin-dir /usr/local/bin; pnpm remove -g corepack fallow @openai/codex @anthropic-ai/claude-code @technomoron/agent-run ripgrep rg pm2 tsx typescript; fi'
ExecStart=/usr/local/bin/npm install -g --force fallow@latest ripgrep@latest pm2@latest tsx@latest typescript@latest @openai/codex@latest @anthropic-ai/claude-code@latest @technomoron/agent-run@latest
ExecStartPost=-/bin/sh -c 'if /usr/local/bin/pm2 ping >/dev/null 2>&1; then /usr/bin/timeout 120 /usr/local/bin/pm2 update; fi'
```

Create `/etc/systemd/system/ai-tools-update.timer`:

```ini
[Unit]
Description=Run AI tool updater hourly

[Timer]
OnBootSec=10m
OnUnitActiveSec=1h
AccuracySec=5m
Unit=ai-tools-update.service

[Install]
WantedBy=timers.target
```

Enable it with:

```sh
systemctl daemon-reload
systemctl enable --now ai-tools-update.timer
systemd-analyze verify /etc/systemd/system/ai-tools-update.service /etc/systemd/system/ai-tools-update.timer
```

If `/usr/local/share/pnpm` is symlinked to another filesystem for disk space, keep the symlink and make the target root-owned `0755`. Do not replace the symlink unless the user explicitly asks to move storage.

### Windows

Windows does not use systemd. Use an elevated PowerShell scheduled task that runs as `SYSTEM`. Use machine-wide npm/pnpm paths so non-admin global installs fail.

Create `C:\ProgramData\ai-tools-update\ai-tools-update.ps1`:

```powershell
$ErrorActionPreference = "Stop"

$NpmPrefix = "C:\Program Files\nodejs"
$PnpmGlobal = "C:\ProgramData\pnpm\global"
$PnpmBin = "C:\Program Files\nodejs"

New-Item -ItemType Directory -Force -Path $PnpmGlobal | Out-Null
[Environment]::SetEnvironmentVariable("PNPM_HOME", $PnpmBin, "Machine")

npm config set prefix $NpmPrefix --location=global
pnpm config set --global global-dir $PnpmGlobal
pnpm config set --global global-bin-dir $PnpmBin

npm install -g --force npm@latest pnpm@latest corepack@latest

pnpm remove -g corepack fallow @openai/codex @anthropic-ai/claude-code @technomoron/agent-run ripgrep rg pm2 tsx typescript 2>$null

npm install -g --force `
  fallow@latest `
  ripgrep@latest `
  pm2@latest `
  tsx@latest `
  typescript@latest `
  @openai/codex@latest `
  @anthropic-ai/claude-code@latest `
  @technomoron/agent-run@latest

try {
  pm2 ping *> $null
  pm2 update
} catch {
  # pm2 is not running; package update is still complete.
}
```

Register the scheduled task from elevated PowerShell:

```powershell
New-Item -ItemType Directory -Force -Path "C:\ProgramData\ai-tools-update" | Out-Null
$Action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"C:\ProgramData\ai-tools-update\ai-tools-update.ps1`""
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(10) -RepetitionInterval (New-TimeSpan -Hours 1)
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
Register-ScheduledTask -TaskName "ai-tools-update" -Action $Action -Trigger $Trigger -Principal $Principal -Description "Update approved global AI CLI and package-manager tools"
```

Validate Windows policy from elevated PowerShell:

```powershell
npm prefix -g
npm list -g --depth=0
pnpm config get global-dir
pnpm config get global-bin-dir
pnpm list -g --depth 0
Get-ScheduledTask -TaskName ai-tools-update
```

The expected Windows result is that npm and pnpm global bins both resolve to `C:\Program Files\nodejs`, pnpm's package repository resolves to `C:\ProgramData\pnpm\global`, and non-admin users cannot write either location.
