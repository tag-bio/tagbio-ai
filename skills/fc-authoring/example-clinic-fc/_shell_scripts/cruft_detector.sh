#!/usr/bin/bash
# Report unused / stale collateral in the FC (orphaned parsers, data_functions, protocols...).
# cruft=true prints a report; cruft=purge would delete the detected cruft (use with care).
# Engine jars: default to ./_jars (populated by tagbio-ai/setup.sh); override with TAGBIO_JARS for a local build.
JARS="${TAGBIO_JARS:-$(cd "$(dirname "$0")/.." && pwd)/_jars}"

java -Xmx4g \
    -jar ${JARS}/fc_csv_server.jar \
    manifest=manifest.json \
    cruft=true
