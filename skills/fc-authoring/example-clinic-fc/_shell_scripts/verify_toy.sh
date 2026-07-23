#!/usr/bin/env bash
# verify_toy.sh — end-to-end check that the toy example works against the CURRENTLY-INSTALLED R and
# Python SDKs. Use it after any tagbio / tagbiopy change to catch regressions:
#   1. builds the archive,
#   2. serves it (run_server runs every registered PROTOCOL's test on startup),
#   3. runs every AD-HOC client script (_r/*.R, _python/*.py) against the served FC,
#   4. prints a PASS/FAIL summary and exits non-zero if anything failed.
#
# Env (all have sensible defaults via run_server.sh / build_archive.sh):
#   TAGBIO_JARS   dir with fc_csv_server.jar        (e.g. ~/workspace/fc)
#   TAGBIO_R_UTILS  R SDK repo checkout             (e.g. ~/workspace/tagbio)   -> r_sdk=
#   TAGBIO_PY       Python SDK repo checkout        (e.g. ~/workspace/tagbiopy) -> python_sdk=
#   PYTHON          python interpreter              (default: python)
#
# Usage (from anywhere):  bash <toy>/_shell_scripts/verify_toy.sh
set -uo pipefail

FC_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$FC_DIR"
PYBIN="${PYTHON:-python}"
LOG="$(mktemp -t verify_toy.XXXXXX.log)"
FAILURES=0

echo "== SDK versions under test =="
Rscript -e 'cat("  tagbio (R):  ", as.character(packageVersion("tagbio")), "\n")' 2>/dev/null || echo "  tagbio (R): NOT INSTALLED"
"$PYBIN" -c "import tagbiopy; print('  tagbiopy:   ', tagbiopy.__version__)" 2>/dev/null || echo "  tagbiopy: NOT INSTALLED"

echo "== archive (best-effort rebuild; fixture fallback) =="
# The harness tests SDK query paths against a served FC, not the build. Rebuild if we can, but the
# committed archive.ser is a valid fixture, so a build hiccup must not block the SDK checks.
if bash _shell_scripts/build_archive.sh > "$LOG" 2>&1 && [ -f archive.ser ]; then
  echo "  archive rebuilt"
elif [ -f archive.ser ]; then
  echo "  build did not complete — using the committed archive.ser (fixture). Build tail:"
  tail -4 "$LOG" | sed 's/^/      /'
else
  echo "  build failed AND no archive.ser present — cannot test:"; tail -20 "$LOG" | sed 's/^/      /'; exit 1
fi

echo "== serve + run protocol tests =="
pkill -f 'fc_csv_server.jar run_server' 2>/dev/null; sleep 2   # clear any straggler holding :8000
bash _shell_scripts/run_server.sh > "$LOG" 2>&1 &
SRV=$!
# wait for the startup tests to finish (or a hard timeout). run_tests must be true in the manifest.
SERVED=0
for _ in $(seq 1 120); do
  # match the PROTOCOL-tests end marker ("*** TESTS COMPLETE ***"), NOT "*** AUTO-TESTS COMPLETE ***"
  # (the earlier compiler-integrity pass), whose substring would otherwise break the poll too soon.
  grep -qE '\*\*\* TESTS COMPLETE' "$LOG" 2>/dev/null && { SERVED=1; break; }
  kill -0 "$SRV" 2>/dev/null || { echo "  SERVER EXITED EARLY (see below)"; tail -8 "$LOG" | sed 's/^/      /'; FAILURES=$((FAILURES+1)); break; }
  sleep 2
done
# grep -c prints 0 AND exits non-zero on no match, so read it without a '|| echo' fallback.
PROTO_FAILS=$(grep -c "Test failed" "$LOG" 2>/dev/null); PROTO_FAILS=${PROTO_FAILS:-0}
PROTO_OK=$(grep -c "Test complete" "$LOG" 2>/dev/null);  PROTO_OK=${PROTO_OK:-0}
if [ "$SERVED" = 1 ]; then
  echo "  protocol tests: $PROTO_OK passed, $PROTO_FAILS failed"
else
  echo "  protocol tests: did NOT reach TESTS COMPLETE (timeout/early exit)"; FAILURES=$((FAILURES+1))
fi
if [ "$PROTO_FAILS" -gt 0 ] 2>/dev/null; then
  grep "Test failed" "$LOG" | sed 's/^/    /'; FAILURES=$((FAILURES + PROTO_FAILS))
fi

echo "== ad-hoc client scripts =="
for scr in $(find _r _python -maxdepth 1 -name '*.R' -o -maxdepth 1 -name '*.py' 2>/dev/null | sort); do
  case "$scr" in
    *.R)  runner="Rscript" ;;
    *.py) runner="$PYBIN" ;;
  esac
  if $runner "$scr" > "$LOG.adhoc" 2>&1; then
    echo "  PASS  $scr"
  else
    echo "  FAIL  $scr"; tail -3 "$LOG.adhoc" | sed 's/^/      /'; FAILURES=$((FAILURES+1))
  fi
done

kill "$SRV" 2>/dev/null
pkill -f 'fc_csv_server.jar run_server' 2>/dev/null
rm -f "$LOG" "$LOG.adhoc"

echo
if [ "$FAILURES" -eq 0 ]; then
  echo "ALL GREEN — toy protocols + ad-hoc scripts pass on the installed SDKs."
else
  echo "FAILURES: $FAILURES — see output above."
  exit 1
fi
