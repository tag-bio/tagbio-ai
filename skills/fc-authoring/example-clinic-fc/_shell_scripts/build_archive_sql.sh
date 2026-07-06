#!/usr/bin/bash
# Build the archive from the SQLite database (the SQL variant). First generate the DB, then build.
# A SQL-sourced FC uses the SQL server jar (which also reads CSV/TSV, so it is the superset).
# Run from the example-clinic-fc/ directory.
bash _shell_scripts/make_sqlite.sh
java -Xmx4g \
    -jar ${TAGBIO_JARS}/fc_sql_server.jar \
    build_archive \
    manifest=manifest_sql.json \
    verbosity=4
