---
name: npm-cleanup
description: Audit and clean npm/pnpm global package state on Linux, Unix-like, and Windows hosts. Use when Codex needs to enforce that admin/root-owned global npm installs are limited to approved CLI packages, pnpm has no user-global installs, pnpm global state uses one admin/root-owned repository, updater units or scheduled tasks follow the same policy, and project directories keep using their own package managers and local dependencies.
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
test "$(npm prefix -g)/bin" = /usr/local/bin
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

The compliant result is:

- `npm list -g --depth=0` contains only the allowlisted packages.
- `pnpm list -g --depth 0` is empty or reports no globally installed packages.
- npm and pnpm both resolve global bins to `/usr/local/bin`.
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

If an updater installs non-allowlisted npm globals, remove them from `ExecStart` and uninstall them globally. If an updater leaves pnpm global directories writable by non-root users, fix ownership and permissions before restarting the timer:

```sh
chown -R root:root /usr/local/share/pnpm /usr/local/lib/node_modules
chmod 0755 /usr/local/share/pnpm /usr/local/share/pnpm/global /usr/local/bin /usr/local/lib/node_modules
stat -Lc '%U:%G %a %n' /usr/local/share/pnpm /usr/local/share/pnpm/global /usr/local/bin /usr/local/lib/node_modules
systemctl daemon-reload
systemctl restart <unit>.timer
```

