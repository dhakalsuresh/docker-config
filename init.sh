#!/bin/bash
CURRENT_DIR=$(pwd)

echo "Building docker containers"

docker-compose build
wait

docker-compose up -d
wait

docker exec -it app_project composer install
wait
