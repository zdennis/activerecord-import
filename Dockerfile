# The image for docker-compose.yml's app service, for running the tests in Docker
ARG RUBY_VERSION=3.4
FROM ruby:${RUBY_VERSION}-bookworm

# Set the working directory
WORKDIR /usr/src/app

# Install the database clients
RUN apt-get update -qq && \
    apt-get install -y default-mysql-client postgresql-client vim && \
    apt-get clean

# Set environment variables
ENV AR_VERSION=8.1

# Copy all files
COPY . .

# Install gems. The tests connect to the docker-compose.yml databases through the
# MYSQL_HOST/PG_HOST environment variables read by test/database.default.yml.
RUN bundle install

CMD ["irb"]
