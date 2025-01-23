#!/bin/bash

# Variables
DB_HOST=$(cat "$DB_HOST_FILE")
DB_PORT=$(cat "$DB_PORT_FILE")
SUPER_PASSWORD=$(cat "$SUPER_PASSWORD_FILE")
SUPER_USER=$(cat "$SUPER_USER_FILE")
PASSWORD=$(openssl rand -base64 12)  # Generate a random password
GITLAB_API_URL="${GITLAB_API_URL}/api/v4/projects/$GITLAB_PROJECT_ID/snippets"
MAX_RETRIES=30 # retry attempt
RETRY_DELAY=10 # seconds
CURRENT_TIME=$(TZ=Asia/Jakarta date "+%d-%m-%Y %H:%M") # Get the current date and time

# Function to retry a command
retry_command() {
  local retries=0
  local success=0
  local command=$1
  local check_error=$2  # Pass an optional flag to check for "message" in the response
  local response=""

  while [ $retries -lt $MAX_RETRIES ]; do
    if [ "$check_error" = true ]; then
      # Capture the command output
      response=$(eval "$command")
      error_message=$(echo "$response" | jq -r '.message // .error // empty')

      if [ -n "$error_message" ]; then
        echo "Error: $error_message"
      else
        success=1
        break
      fi
    else
      # Execute the command directly if error check is not needed
      eval "$command" && success=1 && break
    fi

    retries=$((retries + 1))
    echo "Retry $retries/$MAX_RETRIES after failure. Retrying in $RETRY_DELAY seconds..."
    sleep $RETRY_DELAY
  done

  if [ $success -eq 0 ]; then
    echo "Error: Command failed after $MAX_RETRIES retries."

    ERROR_CONTENT="Error: Rolling password for ${DB_USER} failed"
    echo "**** ${ERROR_CONTENT} ****"
    
    # Create a new error snippet in GitLab
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

    exit 1
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
DB_PREFIX_ESCAPED="\\\`${DB_PREFIX}_%\\\`" # Escape backticks properly

# Construct SQL query
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

# Add SSL options to the command if SSL is enabled
if [ "$ENABLE_SSL" = true ]; then
  SQL_COMMAND+=" --ssl --ssl-ca=/etc/my.cnf.d/tls/ca-cert.pem --ssl-cert=/etc/my.cnf.d/tls/client-cert.pem --ssl-key=/etc/my.cnf.d/tls/client-key.pem"
fi

# Retry SQL commands
sql_command="echo \"$QUERY\" | $SQL_COMMAND"
retry_command "$sql_command"

# Check if the SQL command was successful
if [ $? -eq 0 ]; then
  # Fetch and delete existing snippets
  EXISTING_SNIPPET_IDS=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_TOKEN" "$GITLAB_API_URL?project_id=$GITLAB_PROJECT_ID" | jq --arg title "$GITLAB_SNIPPET_TITLE" '.[] | select(.title == $title) | .id')

  if [ -n "$EXISTING_SNIPPET_IDS" ]; then
    echo "**** [$CURRENT_TIME] Deleting existing snippets with title: $GITLAB_SNIPPET_TITLE ****"
    for SNIPPET_ID in $EXISTING_SNIPPET_IDS; do
      delete_command="curl --silent --request DELETE \"$GITLAB_API_URL/$SNIPPET_ID\" --header \"PRIVATE-TOKEN: $GITLAB_TOKEN\""
      retry_command "$delete_command" true
    done
  fi

  # Create a new snippet in GitLab
  echo "**** [$CURRENT_TIME] Call API to create snippet ****"
  create_snippet_command="curl --silent --request POST \"$GITLAB_API_URL\" \
    --header \"PRIVATE-TOKEN: $GITLAB_TOKEN\" \
    --form \"title=$GITLAB_SNIPPET_TITLE\" \
    --form \"file_name=${GITLAB_SNIPPET_TITLE}.md\" \
    --form \"content=$CONTENT\" \
    --form \"visibility=private\""

  retry_command "$create_snippet_command" true

  echo ""
  echo "**** Rolling password for ${DB_USER} successful ****"
  # Optionally, log the new password to a file (ensure this file is secured)
  echo -e "$CONTENT" > "/var/log/secret-${DB_USER}.log"
fi
