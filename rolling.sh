#!/bin/bash

# Variables
DB_HOST=$(cat "$DB_HOST_FILE")
DB_PORT=$(cat "$DB_PORT_FILE")
SUPER_PASSWORD=$(cat "$SUPER_PASSWORD_FILE")
SUPER_USER=$(cat "$SUPER_USER_FILE")
PASSWORD=$(openssl rand -base64 12)
GITLAB_API_URL="${GITLAB_API_URL}/api/v4/projects/$GITLAB_PROJECT_ID/snippets"
MAX_RETRIES=100
RETRY_DELAY=10
CURRENT_TIME=$(TZ=Asia/Jakarta date "+%d-%m-%Y %H:%M")

# Function to retry a command
retry_command() {
  local retries=0
  local success=0
  local command=$1
  local check_error=$2
  local response=""

  while [ $retries -lt $MAX_RETRIES ]; do
    if [ "$check_error" = true ]; then
      response=$(eval "$command")
      error_message=$(echo "$response" | jq -r '.message // .error // empty')

      if [ -n "$error_message" ]; then
        echo "Error: $error_message"
      else
        success=1
        break
      fi
    else
      eval "$command" && success=1 && break
    fi

    retries=$((retries + 1))
    echo "Retry $retries/$MAX_RETRIES after failure. Retrying in $RETRY_DELAY seconds..."
    sleep $RETRY_DELAY
  done

  if [ $success -eq 0 ]; then
    echo "Error: Command failed after $MAX_RETRIES retries."

    delete_existing_snippets

    ERROR_CONTENT="Error: Rolling password for ${DB_USER} failed"
    echo "**** ${ERROR_CONTENT} ****"

    RESPONSE=$(curl --silent --request POST "$GITLAB_API_URL" \
      --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
      --form "title=$GITLAB_SNIPPET_TITLE" \
      --form "file_name=${GITLAB_SNIPPET_TITLE}.md" \
      --form "content=${ERROR_CONTENT}" \
      --form "visibility=private")

    ERROR_MESSAGE=$(echo "$RESPONSE" | jq -r '.message // empty')
    if [ -n "$ERROR_MESSAGE" ]; then
      echo "Error: $ERROR_MESSAGE"
      exit 1
    fi

    exit 1
  fi
}

# Function to delete all existing snippets with the same title
delete_existing_snippets() {
  EXISTING_SNIPPET_IDS=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API_URL" | jq --arg title "$GITLAB_SNIPPET_TITLE" '.[] | select(.title == $title) | .id')

  if [ -n "$EXISTING_SNIPPET_IDS" ]; then
    echo "**** [$CURRENT_TIME] Deleting existing snippets with title: $GITLAB_SNIPPET_TITLE ****"
    for SNIPPET_ID in $EXISTING_SNIPPET_IDS; do
      delete_command="curl --silent --request DELETE \"$GITLAB_API_URL/$SNIPPET_ID\" --header \"PRIVATE-TOKEN: $GITLAB_TOKEN\""
      retry_command "$delete_command" true
    done
  fi
}

# Content for the snippet
CONTENT="\
## Access
**PhpMyAdmin** : [${PMA_URL}](${PMA_URL})  
**Remote Host** : ${DB_REMOTE_HOST}  
**Remote Port** : ${DB_PORT}

## User List
**User PMA** : ${PMA_USER}  
**Pass PMA** : ${PMA_PASS}  

**User DB** : ${DB_USER}  
**Pass DB** : ${PASSWORD}"

# SQL command
SQL_COMMAND="$SQL_SERVICE -u$SUPER_USER -p$SUPER_PASSWORD -h $DB_HOST -P $DB_PORT"
DB_PREFIX_ESCAPED="\\\`${DB_PREFIX}_%\\\`"

if [ "$ENABLE_SSL" = true ]; then
  SSL_REQUIRE="REQUIRE X509"
else
  SSL_REQUIRE=""
fi

QUERY=$(cat <<EOF
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$PASSWORD' $SSL_REQUIRE;
GRANT ALL PRIVILEGES ON ${DB_PREFIX_ESCAPED}.* TO '$DB_USER'@'%';
REVOKE DROP, DELETE ON ${DB_PREFIX_ESCAPED}.* FROM '$DB_USER'@'%';
ALTER USER '$DB_USER'@'%' IDENTIFIED BY '$PASSWORD' $SSL_REQUIRE;
FLUSH PRIVILEGES;
EOF
)

if [ "$ENABLE_SSL" = true ]; then
  SQL_COMMAND+=" --ssl --ssl-ca=/etc/my.cnf.d/tls/ca-cert.pem --ssl-cert=/etc/my.cnf.d/tls/client-cert.pem --ssl-key=/etc/my.cnf.d/tls/client-key.pem"
fi

sql_command="echo \"$QUERY\" | $SQL_COMMAND"
retry_command "$sql_command"

if [ $? -eq 0 ]; then
  delete_existing_snippets

  echo "**** [$CURRENT_TIME] Creating new snippet ****"
  create_snippet_command="curl --silent --request POST \"$GITLAB_API_URL\" \
    --header \"PRIVATE-TOKEN: $GITLAB_TOKEN\" \
    --form \"title=$GITLAB_SNIPPET_TITLE\" \
    --form \"file_name=${GITLAB_SNIPPET_TITLE}.md\" \
    --form \"content=$CONTENT\" \
    --form \"visibility=private\""

  retry_command "$create_snippet_command" true

  echo ""
  echo "**** Rolling password for ${DB_USER} successful ****"

  echo -e "$CONTENT" > "/var/log/secret-${DB_USER}.log"
fi
