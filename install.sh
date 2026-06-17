#!/usr/bin/env bash
set -euo pipefail

repo_url="${AI_SKILLS_REPO_URL:-https://github.com/bjornjac/ai-skills}"
ref="${AI_SKILLS_REF:-main}"
version="${AI_SKILLS_VERSION:-latest}"
dest="${AI_SKILLS_DEST:-}"
codex_dest="${AI_SKILLS_CODEX_DEST:-"${CODEX_HOME:-"$HOME/.codex"}/skills"}"
claude_dest="${AI_SKILLS_CLAUDE_DEST:-"${CLAUDE_HOME:-"$HOME/.claude"}/skills"}"
target="${AI_SKILLS_TARGET:-all}"

usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --dest <path>          Install skills into only this directory
  --target <target>      Install target: all, codex, or claude (default: all)
  --codex-dest <path>    Codex skills directory (default: ${CODEX_HOME:-$HOME/.codex}/skills)
  --claude-dest <path>   Claude skills directory (default: ${CLAUDE_HOME:-$HOME/.claude}/skills)
  --version <v>    Install from release version v, without the leading v (default: latest)
  --latest         Install from the latest GitHub release
  --repo <url>     Repository URL to download when not run from a checkout
  --ref <ref>      Fallback Git ref to download when a release is unavailable (default: main)
  -h, --help       Show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dest)
      shift
      dest="${1:-}"
      ;;
    --dest=*)
      dest="${1#--dest=}"
      ;;
    --target)
      shift
      target="${1:-}"
      ;;
    --target=*)
      target="${1#--target=}"
      ;;
    --codex-dest)
      shift
      codex_dest="${1:-}"
      ;;
    --codex-dest=*)
      codex_dest="${1#--codex-dest=}"
      ;;
    --claude-dest)
      shift
      claude_dest="${1:-}"
      ;;
    --claude-dest=*)
      claude_dest="${1#--claude-dest=}"
      ;;
    --version|-v)
      shift
      version="${1:-}"
      ;;
    --version=*)
      version="${1#--version=}"
      ;;
    --latest)
      version="latest"
      ;;
    --repo)
      shift
      repo_url="${1:-}"
      ;;
    --repo=*)
      repo_url="${1#--repo=}"
      ;;
    --ref)
      shift
      ref="${1:-}"
      ;;
    --ref=*)
      ref="${1#--ref=}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [ -z "$repo_url" ] || [ -z "$ref" ] || [ -z "$version" ] || [ -z "$target" ]; then
  echo "--repo, --ref, --version, and --target must not be empty" >&2
  exit 1
fi

case "$target" in
  all|codex|claude) ;;
  *)
    echo "--target must be one of: all, codex, claude" >&2
    exit 1
    ;;
esac

tmp=
cleanup() {
  if [ -n "$tmp" ] && [ -d "$tmp" ]; then
    rm -rf "$tmp"
  fi
}
trap cleanup EXIT INT HUP TERM

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

download() {
  url=$1
  out=$2

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out" && return 0
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url" && return 0
  else
    echo "Missing required command: curl or wget" >&2
    exit 1
  fi

  return 1
}

release_archive_url() {
  case "$version" in
    latest)
      printf '%s\n' "$repo_url/releases/latest/download/installer.tgz"
      ;;
    v*)
      printf '%s\n' "$repo_url/releases/download/$version/installer.tgz"
      ;;
    *)
      printf '%s\n' "$repo_url/releases/download/v$version/installer.tgz"
      ;;
  esac
}

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" 2>/dev/null && pwd)

if [ -f "$script_dir/install.sh" ] && [ -d "$script_dir/skills" ]; then
  src=$script_dir/skills
else
  need_cmd tar
  tmp=$(mktemp -d "${TMPDIR:-/tmp}/ai-skills.XXXXXX")
  archive=$tmp/ai-skills.tar.gz

  if ! download "$(release_archive_url)" "$archive"; then
    echo "Release archive unavailable; falling back to $ref branch archive..." >&2
    download "$repo_url/archive/refs/heads/$ref.tar.gz" "$archive"
  fi

  tar -xzf "$archive" -C "$tmp"
  src=$(find "$tmp" -type d -name skills | head -n 1)

  if [ -z "$src" ] || [ ! -d "$src" ]; then
    echo "Could not find skills directory in downloaded archive" >&2
    exit 1
  fi
fi

install_to() {
  install_dest=$1
  label=$2

  if [ -z "$install_dest" ]; then
    echo "$label destination must not be empty" >&2
    exit 1
  fi

  mkdir -p "$install_dest"

  installed=
  for skill in "$src"/*; do
    [ -d "$skill" ] || continue
    [ -f "$skill/SKILL.md" ] || continue

    name=$(basename "$skill")
    skill_target=$install_dest/$name
    staging=$install_dest/.$name.installing

    rm -rf "$staging"
    cp -R "$skill" "$staging"
    rm -rf "$skill_target"
    mv "$staging" "$skill_target"

    installed="${installed}${installed:+ }$name"
  done

  if [ -z "$installed" ]; then
    echo "No skills found to install" >&2
    exit 1
  fi

  echo "Installed $label skills to $install_dest:"
  for name in $installed; do
    echo "  - $name"
  done
}

if [ -n "$dest" ]; then
  install_to "$dest" "custom"
else
  case "$target" in
    all)
      install_to "$codex_dest" "Codex"
      install_to "$claude_dest" "Claude"
      ;;
    codex)
      install_to "$codex_dest" "Codex"
      ;;
    claude)
      install_to "$claude_dest" "Claude"
      ;;
  esac
fi
