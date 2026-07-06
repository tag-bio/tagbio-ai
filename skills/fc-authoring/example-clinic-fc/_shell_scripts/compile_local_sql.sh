#!/usr/bin/bash
# SQL variant of compile_local.sh: validate config_sql + protocols WITHOUT loading data — fast.
# Uses the SQL server jar and manifest_sql.json. Run after editing the SQL config or protocols.
java -Xmx4g \
    -jar ${TAGBIO_JARS}/fc_sql_server.jar \
    compile \
    manifest=manifest_sql.json
