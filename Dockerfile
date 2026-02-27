FROM ruby:3.3-slim

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
      build-essential \
      git \
      libsqlite3-dev \
      sqlite3 \
      nodejs \
      npm \
      curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /gem

# Copy dependency manifest files first for better layer caching.
# The gemspec references lib/extendable_rails/version.rb, so we must
# copy it before running bundle install.
COPY extendable-rails.gemspec Gemfile ./
COPY lib/extendable_rails/version.rb lib/extendable_rails/version.rb

# Install gem dependencies
RUN bundle install

# Copy remaining source files
COPY . .

# Default command: run the full RSpec test suite
CMD ["bundle", "exec", "rspec", "--format", "documentation"]
