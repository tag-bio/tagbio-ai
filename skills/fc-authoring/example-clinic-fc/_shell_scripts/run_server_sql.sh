#!/usr/bin/bash
# Serve the SQL-variant archive locally. Loading an archive never touches the source, so this
# serves exactly like the CSV variant -- the SQL vs CSV difference is only at build time.
# Run from the example-clinic-fc/ directory. R/Python SDKs are needed for plugin protocols.
java -Xmx4g \
    -jar ${TAGBIO_JARS}/fc_sql_server.jar \
    run_server \
    manifest=manifest_sql.json \
    r_sdk=${TAGBIO_R_UTILS} \
    python_sdk=${TAGBIO_PY}
