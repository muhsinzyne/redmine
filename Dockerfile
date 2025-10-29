# Redmine with WorkProof Plugin - Production Dockerfile
FROM ruby:2.7.8-slim

# Set environment variables
ENV RAILS_ENV=production \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    default-libmysqlclient-dev \
    git \
    imagemagick \
    libmagickwand-dev \
    ghostscript \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /usr/src/redmine

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test --jobs 4 --retry 3

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p tmp/pdf tmp/pids log files public/plugin_assets \
    && chmod -R 755 tmp log files public/plugin_assets

# Generate secret key base at build time (will be overridden by env var)
RUN bundle exec rake generate_secret_token

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:3000/ || exit 1

# Start Puma server
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]

