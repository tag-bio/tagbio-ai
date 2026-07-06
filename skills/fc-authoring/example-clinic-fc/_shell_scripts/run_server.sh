#!/usr/bin/bash
# Load the archive and serve the protocols over the API (and UI).
# Run from the example-clinic-fc/ directory. R/Python SDKs are needed for plugin protocols.
java -Xmx4g \
    -jar ${TAGBIO_JARS}/fc_csv_server.jar \
    run_server \
    manifest=manifest.json \
    r_sdk=${TAGBIO_R_UTILS} \
    python_sdk=${TAGBIO_PY}
