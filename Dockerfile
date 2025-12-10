FROM ruby:2.1.10

WORKDIR /app

# # Install system dependencies
# RUN apt-get update -qq && apt-get install -y \
#     build-essential \
#     libmysqlclient-dev \
#     mysql-client \
#     nodejs \
#     && rm -rf /var/lib/apt/lists/*

# Copy Gemfile and Gemfile.lock
COPY Gemfile Gemfile.lock ./

# Install Ruby dependencies
ENV BUNDLER_VERSION=1.10.5
RUN gem install bundler -v 1.10.5
RUN bundle install

# # Copy application code
COPY . .
#
# # Expose port 3000
# EXPOSE 5000

# # Start the application
# CMD ["bundle", "exec", "unicorn", "-p", "3000"]
