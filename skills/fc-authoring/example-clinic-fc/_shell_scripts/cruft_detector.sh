#!/usr/bin/bash
# Report unused / stale collateral in the FC (orphaned parsers, data_functions, protocols...).
# cruft=true prints a report; cruft=purge would delete the detected cruft (use with care).
java -Xmx4g \
    -jar ${TAGBIO_JARS}/fc_csv_server.jar \
    manifest=manifest.json \
    cruft=true
