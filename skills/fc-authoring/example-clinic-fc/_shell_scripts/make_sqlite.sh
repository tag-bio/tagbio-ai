#!/usr/bin/bash
# Build a SQLite database (data/clinic.db) from the same source files the CSV config uses,
# so the SQL variant of the FC (config_sql.json / manifest_sql.json) has a database to read.
# The DB is a generated artifact (gitignored) — regenerate it any time from the CSV/TSV sources.
# Run from the example-clinic-fc/ directory.
set -Eeuo pipefail

db="data/clinic.db"
rm -f "$db"

# Each .import creates a table using the file's header row as column names.
sqlite3 "$db" <<'SQL'
.mode csv
.import data/patients.csv patients
.import data/encounters.csv encounters
.import data/labs.csv labs
.import data/departments.csv departments
.mode tabs
.import data/genotypes.tsv genotypes
SQL

echo "Built $db:"
sqlite3 "$db" ".tables"
