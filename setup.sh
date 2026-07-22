#!/usr/bin/env bash
# Universal Tag.bio SDK setup. Clones the R and Python SDK repos as siblings of tagbio-ai and
# OPTIONALLY installs the one(s) you choose. Cloning is cheap and safe; installing changes your
# environment, so it is opt-in — a Python dev needn't install R, and vice-versa.
#
# Usage (from the tagbio-ai repo root; a data-product repo's _AI/setup.sh delegates here):
#   bash setup.sh                # clone both SDK repos; install nothing
#   bash setup.sh --python       # + install the Python SDK (tagbiopy)
#   bash setup.sh --r            # + install the R SDK (tagbio)
#   bash setup.sh --r --python   # + install both
set -euo pipefail

R_SDK_URL="${R_SDK_URL:-https://github.com/tag-bio/tagbio.git}"       # R SDK  (package at tagbio/tagbio)
PY_SDK_URL="${PY_SDK_URL:-https://github.com/tag-bio/tagbiopy.git}"   # Python SDK

install_r=false; install_py=false
for arg in "$@"; do
  case "$arg" in
    --r|--R)       install_r=true ;;
    --python|--py) install_py=true ;;
    -h|--help)     sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $arg  (use --r and/or --python)"; exit 1 ;;
  esac
done

command -v git >/dev/null 2>&1 || { echo "ERROR: git not found on PATH."; exit 1; }
DEST="$(cd "$(dirname "$0")/.." && pwd)"   # parent of tagbio-ai
clone_one() {   # $1 = url
  local dir; dir="$DEST/$(basename "$1" .git)"
  if [ -d "$dir/.git" ]; then
    # Already cloned: pull the latest. SAFE — skip if there are local edits (never clobber), and
    # only fast-forward (never merge/diverge). Non-fatal so setup never aborts on a dirty/offline repo.
    if [ -n "$(git -C "$dir" status --porcelain -uno 2>/dev/null)" ]; then
      echo "  $dir: local changes present — left as-is (commit or stash, then re-run to update)"
    else
      git -C "$dir" pull --ff-only --quiet 2>/dev/null \
        && echo "  $dir: pulled latest" \
        || echo "  $dir: could not fast-forward (diverged/offline) — left as-is"
    fi
  else
    echo "  cloning $1"; git clone --depth 1 "$1" "$dir"
  fi
}

echo "Cloning SDK repos into: $DEST"
clone_one "$R_SDK_URL"
clone_one "$PY_SDK_URL"

# Toy-local SDK pointers so example-clinic-fc/_shell_scripts default r_sdk/python_sdk to ./_sdk/*
# (mirrors the _jars/ default; run_server still accepts an explicit path or TAGBIO_R_UTILS/TAGBIO_PY).
SDK_LINK_DIR="$(cd "$(dirname "$0")" && pwd)/skills/fc-authoring/example-clinic-fc/_sdk"
mkdir -p "$SDK_LINK_DIR"
ln -sfn "$DEST/tagbio" "$SDK_LINK_DIR/tagbio"
ln -sfn "$DEST/tagbiopy" "$SDK_LINK_DIR/tagbiopy"
echo "Linked SDK pointers into example-clinic-fc/_sdk/"

if $install_r; then
  echo "Installing the R SDK (tagbio) + dependencies ..."
  command -v Rscript >/dev/null 2>&1 || { echo "ERROR: Rscript not found."; exit 1; }
  Rscript -e "if (!requireNamespace('remotes', quietly=TRUE)) install.packages('remotes', repos='https://cloud.r-project.org'); remotes::install_local('$DEST/tagbio/tagbio', dependencies=TRUE, upgrade='never')"
fi
if $install_py; then
  echo "Installing the Python SDK (tagbiopy) ..."
  command -v pip >/dev/null 2>&1 || { echo "ERROR: pip not found."; exit 1; }
  pip install "$DEST/tagbiopy"
fi

# --- FC engine jars for the runnable toy example (skills/fc-authoring/example-clinic-fc) ---
# The toy example's _shell_scripts default to running the engine from example-clinic-fc/_jars/
# (override with TAGBIO_JARS). These are large binaries: gitignored and downloaded, not committed.
TAGBIO_JARS_URL="${TAGBIO_JARS_URL:-PUBLIC_JAR_BASE_URL_TBD}"   # TODO(Jesse+Sanjay): the public jar base URL
JARS_DIR="$(cd "$(dirname "$0")" && pwd)/skills/fc-authoring/example-clinic-fc/_jars"
echo
echo "Provisioning FC engine jars for the toy example ..."
if [ "$TAGBIO_JARS_URL" = "PUBLIC_JAR_BASE_URL_TBD" ]; then
  echo "  Public jar download is coming shortly (URL being finalized) — skipping fetch for now."
  echo "  Interim: place fc_csv_server.jar + fc_sql_server.jar in"
  echo "    skills/fc-authoring/example-clinic-fc/_jars/  (or set TAGBIO_JARS to your own jar dir)."
elif ! command -v curl >/dev/null 2>&1; then
  echo "  curl not found — skipping jar download."
else
  mkdir -p "$JARS_DIR"
  for j in fc_csv_server.jar fc_sql_server.jar; do
    if [ -f "$JARS_DIR/$j" ]; then echo "  already present: $j"
    else echo "  fetching $j"; curl -fsSL "$TAGBIO_JARS_URL/$j" -o "$JARS_DIR/$j" || echo "  WARN: could not fetch $j"; fi
  done
fi

echo
echo "Done."
if ! $install_r && ! $install_py; then
  echo "  No SDK installed — re-run with --r and/or --python when ready."
fi
