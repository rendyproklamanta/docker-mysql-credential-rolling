#!/bin/bash

## Create secret
docker secret rm db_host
docker secret rm db_port
docker secret rm db_super_user
docker secret rm db_super_paswd

echo "mariadb_maxscale" | docker secret create db_host -
echo "6033" | docker secret create db_port -
echo "super_usr" | docker secret create db_super_user -
echo "SUPER_PASSWORD_SET" | docker secret create db_super_paswd -

## Show list secrets
docker secret ls