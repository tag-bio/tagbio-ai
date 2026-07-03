# Blood Pressure report via a Jupyter notebook -- a Tag.bio Python plugin.
# This .py plugin papermill-executes the companion notebook (bp_report.ipynb) and returns HTML.
# The .py plugin papermill-runs the companion notebook, which loads the analysis frame via
# FCPacket + TagbioData from tagbiopy.protocol.
import os

import papermill as pm
from tagbiopy.protocol import TagbioData, TagbioResult
from tagbiopy.utils import ipynb_to_html

NOTEBOOK = 'bp_report.ipynb'


def run_ipynb(tag_data: TagbioData, tag_result: TagbioResult):
    this_dir = os.path.dirname(os.path.realpath(__file__))
    notebook = os.path.join(this_dir, NOTEBOOK)
    executed = os.path.join(this_dir, '_bp_report_out.ipynb')

    # The server writes the analysis parameters to a json file at tag_data.fc_packet.filename;
    # pass it into the notebook so it can load the analysis frame.
    pm.execute_notebook(
        notebook,
        executed,
        parameters={'fc_packet': tag_data.fc_packet.filename},
    )

    ipynb_to_html(executed, tag_result.path)
    return tag_result
