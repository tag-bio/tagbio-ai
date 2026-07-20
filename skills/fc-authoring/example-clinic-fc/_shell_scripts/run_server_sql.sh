#!/usr/bin/bash
# Serve the SQL-variant archive locally. Loading an archive never touches the source, so this
# serves exactly like the CSV variant -- the SQL vs CSV difference is only at build time.
# Run from the example-clinic-fc/ directory. R/Python SDKs are needed for plugin protocols.
# Engine jars: default to ./_jars (populated by tagbio-ai/setup.sh); override with TAGBIO_JARS for a local build.
JARS="${TAGBIO_JARS:-$(cd "$(dirname "$0")/.." && pwd)/_jars}"
# R/Python SDKs: default to ./_sdk/* (linked by tagbio-ai/setup.sh); override with TAGBIO_R_UTILS / TAGBIO_PY.
R_SDK="${TAGBIO_R_UTILS:-$(cd "$(dirname "$0")/.." && pwd)/_sdk/tagbio}"
PY_SDK="${TAGBIO_PY:-$(cd "$(dirname "$0")/.." && pwd)/_sdk/tagbiopy}"

java -Xmx4g \
    -jar ${JARS}/fc_sql_server.jar \
    run_server \
    manifest=manifest_sql.json \
    r_sdk=${R_SDK} \
    python_sdk=${PY_SDK}
