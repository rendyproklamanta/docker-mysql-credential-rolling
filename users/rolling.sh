#!/bin/bash

# Variables
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

# Fetch existing snippets and delete the one with the matching title
EXISTING_SNIPPET_ID=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API_URL?project_id=$GITLAB_PROJECT_ID" | jq --arg title "$GITLAB_SNIPPET_TITLE" '.[] | select(.title == $title) | .id')

if [ -n "$EXISTING_SNIPPET_ID" ]; then
  echo "**** Delete existing snippet ID: $EXISTING_SNIPPET_ID ****"
  echo ""
  curl --silent --request DELETE "$GITLAB_API_URL/$EXISTING_SNIPPET_ID" --header "PRIVATE-TOKEN: $GITLAB_TOKEN"
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
  echo "Error: $ERROR_MESSAGE"
  exit 1
fi

echo "**** Create snippet project ID ${GITLAB_PROJECT_ID} successfuly ****"
echo ""

# Change the user password or create user if not exists
mariadb -u$SUPER_USER -p${SUPER_PASSWORD} -h $DB_HOST -P $DB_PORT <<EOF
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$PASSWORD';

GRANT ALL PRIVILEGES ON \`${DB_PREFIX}_%\`.* TO '$DB_USER'@'%';

-- Revoke destructive privileges
REVOKE DROP, LOCK TABLES, ALTER, DELETE ON \`${DB_PREFIX}_%\`.* FROM '$DB_USER'@'%';

ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$PASSWORD';
FLUSH PRIVILEGES;
EOF

echo "**** Rolling password ${DB_USER} successfuly ****"
echo ""

# Optionally, log the new password to a file (ensure this file is secured)
echo -e "$CONTENT" > /var/log/secret-${DB_USER}.log