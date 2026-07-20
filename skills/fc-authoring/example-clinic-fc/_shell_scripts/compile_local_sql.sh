#!/usr/bin/bash
# SQL variant of compile_local.sh: validate config_sql + protocols WITHOUT loading data — fast.
# Uses the SQL server jar and manifest_sql.json. Run after editing the SQL config or protocols.
# Engine jars: default to ./_jars (populated by tagbio-ai/setup.sh); override with TAGBIO_JARS for a local build.
JARS="${TAGBIO_JARS:-$(cd "$(dirname "$0")/.." && pwd)/_jars}"

java -Xmx4g \
    -jar ${JARS}/fc_sql_server.jar \
    compile \
    manifest=manifest_sql.json
