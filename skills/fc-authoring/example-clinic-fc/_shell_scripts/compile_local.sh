#!/usr/bin/bash
# Validate the config + protocols without a full build: it parses config and compiles the
# protocols, then stops when it would load data. Run this after editing config or parsers to
# catch JSON/YAML and reference errors fast. (die=true exits after validation.)
java -Xmx4g \
    -jar ${TAGBIO_JARS}/fc_csv_server.jar \
    manifest=manifest.json \
    die=true
