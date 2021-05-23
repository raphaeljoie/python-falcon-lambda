#!/bin/bash

# Remove previously generated files
rm -rf build/packages
rm build/lambda.zip

set -e

# Activate venv
source /venv/bin/activate
# Install requirements in a separated folder
pip install -r requirements.txt --target build/packages
# Append requirements to zip archive
cd build/packages
zip -r ../../build/lambda.zip *
# Append source to zip archive
cd ../..
zip -r build/lambda.zip * -x "venv/*" "__pycache__/*" "bin/*" ".idea/*" "build/*"
