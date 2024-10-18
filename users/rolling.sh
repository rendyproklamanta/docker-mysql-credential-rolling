#!/bin/bash

# Variables
DB_HOST=$(cat "$DB_HOST_FILE")
DB_PORT=$(cat "$DB_PORT_FILE")
SUPER_PASSWORD=$(cat "$SUPER_PASSWORD_FILE")
SUPER_USER=$(cat "$SUPER_USER_FILE")
PASSWORD=$(openssl rand -base64 12)  # Generate a random password
GITLAB_API_URL="${GITLAB_API_URL}/api/v4/projects/$GITLAB_PROJECT_ID/snippets"

# Content for the snippet
CONTENT="
## Access
**PhpMyAdmin** : [${PMA_URL}](${PMA_URL})  
**Remote Host** : ${DB_REMOTE_HOST}  
**Remote Port** : ${DB_PORT}

## User List
**User PMA** : ${PMA_USER}  
**Pass PMA** : ${PMA_PASS}  
  
**User DB** : ${DB_USER}  
**Pass DB** : ${PASSWORD}"

# Fetch existing snippets
EXISTING_SNIPPET_IDS=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API_URL?project_id=$GITLAB_PROJECT_ID" | jq --arg title "$GITLAB_SNIPPET_TITLE" '.[] | select(.title == $title) | .id')

if [ -n "$EXISTING_SNIPPET_IDS" ]; then
  # Loop through each snippet ID and delete it
  echo "**** Deleting existing snippets with title: $GITLAB_SNIPPET_TITLE ****"
  echo ""
  
  # Convert the IDs to an array
  for SNIPPET_ID in $EXISTING_SNIPPET_IDS; do
    echo "**** Delete existing snippet ID: $SNIPPET_ID ****"
    curl --silent --request DELETE "$GITLAB_API_URL/$SNIPPET_ID" --header "PRIVATE-TOKEN: $GITLAB_TOKEN"
  done
fi

# Create a new snippet in GitLab
RESPONSE=$(curl --silent --request POST "$GITLAB_API_URL" \
  --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  --form "title=$GITLAB_SNIPPET_TITLE" \
  --form "file_name=${GITLAB_SNIPPET_TITLE}.md" \
  --form "content=$CONTENT" \
  --form "visibility=private")

# Check for errors in the response
ERROR_MESSAGE=$(echo "$RESPONSE" | jq -r '.message // empty')

if [ -n "$ERROR_MESSAGE" ]; then
  STAGE_STATUS="FAILED"
  exit 1
fi

echo "**** Create snippet project ID ${GITLAB_PROJECT_ID} successfuly ****"
echo ""

STAGE_STATUS="SUCCESS"

## ------------------------------------------------------------------------------------

# SQL command
SQL_COMMAND="$SQL_SERVICE -u$SUPER_USER -p$SUPER_PASSWORD -h $DB_HOST -P $DB_PORT"
QUERY="CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$PASSWORD'"

# Add SSL options if ENABLE_SSL is true
if [ "$ENABLE_SSL" = true ]; then
    SQL_COMMAND+=" --ssl --ssl-ca=/etc/my.cnf.d/tls/ca-cert.pem --ssl-cert=/etc/my.cnf.d/tls/client-cert.pem --ssl-key=/etc/my.cnf.d/tls/client-key.pem"
    QUERY+=" REQUIRE X509"
fi

# Change the user password or create user if not exists
SQL_OUTPUT=$($SQL_COMMAND <<EOF

$QUERY;
GRANT ALL PRIVILEGES ON \`${DB_PREFIX}_%\`.* TO '$DB_USER'@'%';

-- Revoke destructive privileges
REVOKE DROP, LOCK TABLES, ALTER, DELETE ON \`${DB_PREFIX}_%\`.* FROM '$DB_USER'@'%';

ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$PASSWORD';
FLUSH PRIVILEGES;
EOF
)

# Check if the query was successful
if [ $? -eq 0 ]; then
  echo "**** Rolling password for ${DB_USER} successful ****"
  # Optionally, log the new password to a file (ensure this file is secured)
  echo -e "$CONTENT" > /var/log/secret-${DB_USER}.log
  STAGE_STATUS="SUCCESS"
else
  STAGE_STATUS="FAILED"
fi

if [ "$STAGE_STATUS" == "FAILED" ]; then
  ERROR_CONTENT="Error: Rolling password for ${DB_USER} failed"
  echo "**** ${ERROR_CONTENT} ****"
  # Create a new snippet in GitLab
  RESPONSE=$(curl --silent --request POST "$GITLAB_API_URL" \
    --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
    --form "title=$GITLAB_SNIPPET_TITLE" \
    --form "file_name=${GITLAB_SNIPPET_TITLE}.md" \
    --form "content=${ERROR_CONTENT}" \
    --form "visibility=private")

  # Check for errors in the response
  ERROR_MESSAGE=$(echo "$RESPONSE" | jq -r '.message // empty')

  if [ -n "$ERROR_MESSAGE" ]; then
    echo "Error: $ERROR_MESSAGE"
    exit 1
  fi
fi