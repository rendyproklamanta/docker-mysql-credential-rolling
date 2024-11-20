#!/bin/bash

# Build image
docker build -t mysql-user-rolling .

# Remove stack
docker stack rm mysql-user

# Add user1
docker stack deploy --compose-file docker-compose.user.yaml --detach=false mysql-user

# Add user2
# docker stack deploy --compose-file docker-compose.user2.yaml --detach=false mysql-user