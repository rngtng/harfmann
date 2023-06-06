FROM ruby:latest

RUN set -ex \
    && apt-get update \
    && apt-get install -y --no-install-recommends jq

WORKDIR /output
WORKDIR /app

COPY ./src/Gemfile ./src/Gemfile.lock /app/

RUN bundle install
RUN bundle binstubs --all --path /bin

COPY ./src /app

ENV HISTCONTROL=ignoreboth:erasedups
ENV PATH=/app/exec:$PATH

# CMD ["bash"]
