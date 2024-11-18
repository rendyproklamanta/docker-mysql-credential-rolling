#!/bin/bash

## Create secret
docker secret rm db_host
docker secret rm db_port
docker secret rm db_superadmin
docker secret rm db_superadmin_paswd

echo "mariadb_maxscale" | docker secret create db_host -
echo "6033" | docker secret create db_port -
echo "super_adm" | docker secret create db_superadmin -
echo "SUPERADMIN_PASSWORD_SET" | docker secret create db_superadmin_paswd -

## Show list secrets
docker secret ls