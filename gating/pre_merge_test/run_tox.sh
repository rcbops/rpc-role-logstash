#!/bin/bash

## Shell Opts ----------------------------------------------------------------

set -euv
set -o pipefail

## Main ----------------------------------------------------------------------

apt-get update

pip install tox

tmp_tox_dir=$(mktemp -d)
tox -e $RE_JOB_SCENARIO --workdir $tmp_tox_dir
