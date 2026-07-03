#!/usr/bin/bash
# Validate the config + protocols WITHOUT loading data: parse config, register and compile the
# protocols, check test coverage, then exit gracefully — fast. Run after editing config, parsers,
# or protocols to catch JSON/YAML and reference errors without a full build.
java -Xmx4g \
    -jar ${TAGBIO_JARS}/fc_csv_server.jar \
    compile \
    manifest=manifest.json
