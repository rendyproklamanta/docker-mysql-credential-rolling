# Use the logiqx/mysql-client image as the base image
FROM logiqx/mysql-client

# Switch to root user
USER root

# Install necessary packages
RUN apk add --no-cache bash curl jq openssl curl tzdata nano

# Copy the script into the container
COPY rolling.sh /usr/local/bin/rolling.sh
COPY cron.sh /usr/local/bin/cron.sh

# Make the script executable
RUN chmod +x /usr/local/bin/rolling.sh
RUN chmod +x /usr/local/bin/cron.sh

# Add a cron job to run the script every 4 hours or more
RUN echo "0 */4 * * * /usr/local/bin/cron.sh >> /var/log/rolling.log 2>&1" > /etc/crontab

RUN crontab /etc/crontab

# Run crond
CMD ["/bin/bash", "-c", "/usr/local/bin/rolling.sh & crond -f"]