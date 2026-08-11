#!/usr/bin/env bash
# Wire the public Tag.bio AI skills repo (github.com/tag-bio/tagbio-ai) into Claude Code as
# companion skills for `tagbio-analysis`.
#
# It clones (or fast-forward updates) the repo and links every skill it ships into
# ~/.claude/skills/, so `/fc-authoring` becomes available alongside `/tagbio-analysis`.
#
# Deliberately conservative: no SDK install, no jar download, no writes outside the checkout
# directory and ~/.claude/skills. Idempotent — safe to re-run. It never overwrites a real
# (non-symlink) directory of the same name, and never clobbers local edits in the checkout.
#
# Usage:
#   bash install-companions.sh                    # clone/update ~/tagbio-ai, link its skills
#   bash install-companions.sh --dir /opt/tagbio-ai
#   bash install-companions.sh --copy             # copy instead of symlink
#   bash install-companions.sh --no-clone         # link an existing checkout; no network
set -euo pipefail

REPO_URL="${TAGBIO_AI_URL:-https://github.com/tag-bio/tagbio-ai.git}"
DEST="${TAGBIO_AI_DIR:-$HOME/tagbio-ai}"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
SELF_SKILL="tagbio-analysis"          # this skill — never overwrite it from the repo
mode="link"; do_clone=true

while [ $# -gt 0 ]; do
  case "$1" in
    --dir)      DEST="$2"; shift 2 ;;
    --copy)     mode="copy"; shift ;;
    --no-clone) do_clone=false; shift ;;
    -h|--help)  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1  (see --help)" >&2; exit 1 ;;
  esac
done

if $do_clone; then
  command -v git >/dev/null 2>&1 || { echo "ERROR: git not found on PATH." >&2; exit 1; }
  if [ -d "$DEST/.git" ]; then
    if [ -n "$(git -C "$DEST" status --porcelain -uno 2>/dev/null)" ]; then
      echo "  $DEST: local changes present — left as-is (commit or stash, then re-run)"
    elif git -C "$DEST" pull --ff-only --quiet 2>/dev/null; then
      echo "  $DEST: pulled latest"
    else
      echo "  $DEST: could not fast-forward (diverged or offline) — left as-is"
    fi
  else
    echo "  cloning $REPO_URL -> $DEST"
    git clone --depth 1 "$REPO_URL" "$DEST"
  fi
fi

[ -d "$DEST/skills" ] || {
  echo "ERROR: no skills/ directory in $DEST — clone it first (drop --no-clone)." >&2; exit 1; }

mkdir -p "$SKILLS_DIR"
linked=0
for src in "$DEST"/skills/*/; do
  name="$(basename "$src")"
  [ -f "$src/SKILL.md" ] || continue
  [ "$name" = "$SELF_SKILL" ] && { echo "  skipping $name (this skill is authoritative here)"; continue; }
  target="$SKILLS_DIR/$name"

  # Refuse to replace a real directory — that would be someone's own copy of the skill.
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    echo "  $name: $target exists and is not a symlink — left untouched"
    continue
  fi

  if [ "$mode" = "copy" ]; then
    rm -rf "$target"; cp -R "$src" "$target"; echo "  copied  $name"
  else
    ln -sfn "${src%/}" "$target"; echo "  linked  $name -> ${src%/}"
  fi
  linked=$((linked + 1))
done

echo
echo "Wired $linked companion skill(s) into $SKILLS_DIR"
echo "Start a NEW Claude Code session to pick them up, then: /fc-authoring"
if [ "$mode" = "link" ] && [ "$linked" -gt 0 ]; then
  echo "(If a linked skill isn't discovered, re-run with --copy.)"
fi
