#!/usr/bin/bash
# Load the archive and serve the protocols over the API (and UI).
# Run from the example-clinic-fc/ directory. R/Python SDKs are needed for plugin protocols.
# Engine jars: default to ./_jars (populated by tagbio-ai/setup.sh); override with TAGBIO_JARS for a local build.
JARS="${TAGBIO_JARS:-$(cd "$(dirname "$0")/.." && pwd)/_jars}"
# R/Python SDKs: default to ./_sdk/* (linked by tagbio-ai/setup.sh); override with TAGBIO_R_UTILS / TAGBIO_PY.
R_SDK="${TAGBIO_R_UTILS:-$(cd "$(dirname "$0")/.." && pwd)/_sdk/tagbio}"
PY_SDK="${TAGBIO_PY:-$(cd "$(dirname "$0")/.." && pwd)/_sdk/tagbiopy}"

java -Xmx4g \
    -jar ${JARS}/fc_csv_server.jar \
    run_server \
    manifest=manifest.json \
    r_sdk=${R_SDK} \
    python_sdk=${PY_SDK}
