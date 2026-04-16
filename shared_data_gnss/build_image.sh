#!/bin/bash


set -e

trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
trap 'echo "$0: \"${last_command}\" command failed with exit code $?"' ERR

# get the path to this script
MY_PATH=`dirname "$0"`
MY_PATH=`( cd "$MY_PATH" && pwd )`

cd ${MY_PATH}

## --------------------------------------------------------------
## |                            setup                           |
## --------------------------------------------------------------

LOCAL_TAG=shared_data:worlds

# ARCH=amd64
ARCH=amd64

## --------------------------------------------------------------
## |                            build                           |
## --------------------------------------------------------------

if docker pull localhost:5000/alpine &> /dev/null; then
  PATHD='local/Dockerfile'
else
  PATHD='Dockerfile'
fi

docker buildx use default

docker buildx build . --file ${PATHD} --tag $LOCAL_TAG --platform=linux/${ARCH} --no-cache

echo ""
echo "$0: shared data were packed into '$LOCAL_TAG'"
echo ""
