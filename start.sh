#!/bin/bash

# Build image
docker build -t mysql-user-rolling .

# Remove stack
docker stack rm mysql-user

# Deploy
docker stack deploy --compose-file docker-compose.yaml --detach=false mysql-user