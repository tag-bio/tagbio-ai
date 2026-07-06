#!/usr/bin/bash
# Build the immutable, versioned archive from the config + data.
# Run from the example-clinic-fc/ directory (manifest paths are relative to it).
# A CSV/TSV-sourced FC uses the CSV server jar.
java -Xmx4g \
    -jar ${TAGBIO_JARS}/fc_csv_server.jar \
    build_archive \
    manifest=manifest.json \
    verbosity=4
