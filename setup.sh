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
  if [ -d "$dir/.git" ]; then echo "  already present: $dir"; else echo "  cloning $1"; git clone --depth 1 "$1" "$dir"; fi
}

echo "Cloning SDK repos into: $DEST"
clone_one "$R_SDK_URL"
clone_one "$PY_SDK_URL"

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

echo
echo "Done."
if ! $install_r && ! $install_py; then
  echo "  No SDK installed — re-run with --r and/or --python when ready."
fi
