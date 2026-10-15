#!/bin/bash

# This script uses datalad get to fetch raw data from the source directory

set -e

# usage: fetch_raw_data.sh <source_directory>
# where source directory is relative to inputs/raw/
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <source_directory>"
    exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

RAW_DATA_DIR="$SCRIPT_DIR/../inputs/raw"

SOURCE_DIRECTORY="$RAW_DATA_DIR/$1"

# Source the configuration variables.
# (not used currently, but may add functionality in the future)
source "$SCRIPT_DIR/load_site_config.sh"

# TODO: implement fetching raw data using datalad get
# for now, just print
echo "Fetching raw data from: $SOURCE_DIRECTORY"
#datalad get "$SOURCE_DIRECTORY"