#!/bin/bash

## Create secret
sudo docker secret rm db_host
sudo docker secret rm db_port
sudo docker secret rm db_superadmin
sudo docker secret rm db_superadmin_paswd

echo "mariadb_maxscale" | sudo docker secret create db_host -
echo "6033" | sudo docker secret create db_port -
echo "super_adm" | sudo docker secret create db_superadmin -
echo "SUPERADMIN_PASSWORD_SET" | sudo docker secret create db_superadmin_paswd -

## Show list secrets
sudo docker secret ls