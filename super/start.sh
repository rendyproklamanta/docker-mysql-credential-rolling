#!/bin/bash

# Build image
docker build -t mysql-super-rolling .

# Create super
docker stack deploy --compose-file docker-compose.yaml --detach=false mariadb-super