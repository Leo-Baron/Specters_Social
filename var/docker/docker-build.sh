#!/bin/bash

set -o xtrace

docker rmi localhost/specters || true
docker build --target dist -t localhost/specters -f Dockerfile.dev .
docker build --target devcontainer -t localhost/specters-devcontainer -f Dockerfile.dev .
