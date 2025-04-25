#!/bin/bash

# Wait for a random delay between 0 and 30 minutes (0–1800 seconds)
RANDOM_DELAY=$((RANDOM % 1800))
echo "Sleeping for $RANDOM_DELAY seconds before running rolling.sh..."
sleep $RANDOM_DELAY

# Run the actual script
/usr/local/bin/rolling.sh