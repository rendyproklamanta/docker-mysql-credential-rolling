#!/bin/bash

# Build image
docker build -t mysql-user-rolling .

# Remove stack
docker stack rm mysql-username

# Add user1
docker stack deploy --compose-file docker-compose.username.yaml --detach=false mysql-username

# Add user2
# docker stack deploy --compose-file docker-compose.user2.yaml --detach=false mysql-username2