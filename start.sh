#!/bin/bash

# Build image
sudo docker build -t mysql-user-rolling .

# Remove stack
sudo docker stack rm mysql-user

# Deploy
sudo docker stack deploy --compose-file docker-compose.yaml --detach=false mysql-user