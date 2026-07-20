#!/usr/bin/bash
# Build the immutable, versioned archive from the config + data.
# Run from the example-clinic-fc/ directory (manifest paths are relative to it).
# A CSV/TSV-sourced FC uses the CSV server jar.
# Engine jars: default to ./_jars (populated by tagbio-ai/setup.sh); override with TAGBIO_JARS for a local build.
JARS="${TAGBIO_JARS:-$(cd "$(dirname "$0")/.." && pwd)/_jars}"

java -Xmx4g \
    -jar ${JARS}/fc_csv_server.jar \
    build_archive \
    manifest=manifest.json \
    verbosity=4
