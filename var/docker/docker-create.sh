#!/usr/bin/env bash

docker kill specters || true 
docker rm specters || true 
docker create --name specters -p 3000:3000 -p 4200:4200 localhost/specters
