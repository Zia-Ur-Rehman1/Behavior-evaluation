# syntax = docker/dockerfile:1
ARG RUBY_VERSION=3.3.1
FROM ruby:$RUBY_VERSION-slim AS base

WORKDIR /rails

ENV RAILS_ENV="production" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# ---------- build stage ----------
FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git pkg-config libsqlite3-dev

# Copy the gem source into the image so the path dependency resolves
COPY gem/ /gem/

# Copy Gemfile and lock, rewrite the local gem path
COPY Gemfile Gemfile.lock ./
RUN sed -i 's|path: "../.."|path: "/gem"|' Gemfile

RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy application code
COPY . .
# Re-apply the path fix (COPY overwrites the sed change)
RUN sed -i 's|path: "../.."|path: "/gem"|' Gemfile

RUN bundle exec bootsnap precompile --gemfile 2>/dev/null || true
RUN bundle exec bootsnap precompile app/ lib/ 2>/dev/null || true

# Prepare database (sqlite in production for the demo)
RUN SECRET_KEY_BASE=build-only-key bundle exec rails db:create db:migrate db:seed

# Precompile assets
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile 2>/dev/null || true

# ---------- runtime stage ----------
FROM base

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libsqlite3-0 && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build /gem /gem
COPY --from=build /rails /rails

RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER rails:rails

EXPOSE 3000

ENV SECRET_KEY_BASE="change-me-in-production"
ENV GEMINI_API_KEY=""
ENV RAILS_SERVE_STATIC_FILES=1
ENV RAILS_LOG_TO_STDOUT=1

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
