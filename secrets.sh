#!/bin/bash

## Create secret
docker secret rm db_super_user && echo "super_usr" | docker secret create db_super_user -
docker secret rm db_super_paswd && echo "SUPER_PASSWORD_SET" | docker secret create db_super_paswd -

## Show list secrets
docker secret ls