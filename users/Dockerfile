# Use the logiqx/mysql-client image as the base image
FROM logiqx/mysql-client

# Switch to root user
USER root

# Install necessary packages
RUN apk add --no-cache bash curl jq openssl curl

# Copy the script into the container
COPY rolling.sh /usr/local/bin/rolling.sh

# Make the script executable
RUN chmod +x /usr/local/bin/rolling.sh

# Add a cron job to run the script every 4 hours
RUN echo "0 */4 * * * /usr/local/bin/rolling.sh >> /var/log/rolling.log 2>&1" > /etc/crontab

RUN crontab /etc/crontab

# Run crond inside mysql
CMD ["crond", "-f"]