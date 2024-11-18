#!/bin/bash

# Variables
SUPER_PASSWORD="${SUPER_PASSWORD_FILE}"
SUPER_USER="${SUPER_USER_FILE}"
PASSWORD=$(openssl rand -base64 12)  # Generate a random password

# Change the user password or create user if not exists
mariadb -u$SUPER_USER -p${SUPER_PASSWORD} -h $DB_HOST -P $DB_PORT <<EOF
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$PASSWORD';
GRANT ALL PRIVILEGES ON *.* TO '$DB_USER'@'%';
ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$PASSWORD';
FLUSH PRIVILEGES;
EOF

# set docker secrets
docker secret rm db_superadmin_paswd && echo "${PASSWORD}" | docker secret create db_superadmin_paswd -

# log the new password to a file (ensure this file is secured)
echo -e "New password for $DB_USER: $PASSWORD" > /var/log/super.log