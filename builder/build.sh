#!/bin/bash

# Remove previously generated files
rm -rf build/packages

set -e

# Activate venv
source /venv/bin/activate
# Install requirements in a separated folder
pip install -r requirements.txt --target build/packages
