#!/usr/bin/env sh
# Build-time hook for this FC's CONTAINER IMAGE. It installs the R/Python libraries the plugins
# import that are NOT already in the base image. The base image already provides the tidyverse
# (ggplot2, dplyr, tidyr, ...) and the Tag.bio SDKs (tagbio for R, tagbiopy for Python), so only
# the EXTRA packages a plugin uses go here. If a plugin imports a library that is missing here,
# the build/serve fails at load with "no package called '<X>'".
set -ex

# --- R packages used by the R plugins ---------------------------------------
# plugin_bp.R uses plotly; plugin_bp.Rmd uses ggplot2 (already in the tidyverse base).
mamba install -y -c conda-forge \
  r-plotly

# --- Python packages used by the Python plugins -----------------------------
# plugin_bp.py uses plotly; the notebook plugin (plugin_bp_ipynb.py + bp_report.ipynb) uses
# papermill to execute the notebook and nbconvert to render it to HTML.
mamba install -y -c conda-forge \
  plotly \
  papermill \
  nbconvert
