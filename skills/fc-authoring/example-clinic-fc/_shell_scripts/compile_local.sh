#!/usr/bin/bash
# Validate the config + protocols WITHOUT loading data: parse config, register and compile the
# protocols, check test coverage, then exit gracefully — fast. Run after editing config, parsers,
# or protocols to catch JSON/YAML and reference errors without a full build.
# Engine jars: default to ./_jars (populated by tagbio-ai/setup.sh); override with TAGBIO_JARS for a local build.
JARS="${TAGBIO_JARS:-$(cd "$(dirname "$0")/.." && pwd)/_jars}"

java -Xmx4g \
    -jar ${JARS}/fc_csv_server.jar \
    compile \
    manifest=manifest.json
