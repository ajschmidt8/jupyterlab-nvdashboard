#!/bin/bash
# Copyright (c) 2020, NVIDIA CORPORATION.

set -e

# Setup 'gpuci_retry' for upload retries (results in 4 total attempts)
export GPUCI_RETRY_MAX=3
export GPUCI_RETRY_SLEEP=30

# Set default label options if they are not defined elsewhere
export LABEL_OPTION=${LABEL_OPTION:-"--label main"}

# Skip uploads unless BUILD_MODE == "branch"
if [ ${BUILD_MODE} != "branch" ]; then
  echo "Skipping upload"
  return 0
fi

# Skip uploads if there is no upload key
if [ -z "$MY_UPLOAD_KEY" ]; then
  echo "No upload key"
  return 0
fi

if [ -z "$TWINE_PASSWORD" ]; then
  echo "TWINE_PASSWORD not set"
  return 0
fi

if [ -z "$NPM_TOKEN" ]; then
  echo "NPM_TOKEN not set"
  return 0
fi

################################################################################
# SETUP - Get conda file output locations
################################################################################

gpuci_logger "Get conda file output locations"
export JUPYTERLAB_NVDASHBOARD_FILE=`conda build conda/recipes/jupyterlab-nvdashboard --output`

################################################################################
# UPLOAD - Conda packages
################################################################################

gpuci_logger "Starting conda uploads"

gpuci_retry anaconda -t ${MY_UPLOAD_KEY} upload -u ${CONDA_USERNAME:-rapidsai} ${LABEL_OPTION} --skip-existing ${JUPYTERLAB_NVDASHBOARD_FILE}


echo "Upload pypi"
twine upload --skip-existing -u ${TWINE_USERNAME:-rapidsai} dist/*

echo '//registry.npmjs.org/:_authToken=${NPM_TOKEN}' > .npmrc
if [[ "$BUILD_MODE" == "branch" && "${SOURCE_BRANCH}" != 'main' ]]; then
  echo "Nightly build, publishing to npm with nightly tag"
  # Updates package.json version before publishing since previous publications can't be overwritten
  npm version --no-git-tag-version $(git describe --tags)
  npm publish --tag=nightly
else
  npm publish
fi
