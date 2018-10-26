FROM ruby:2.4.5-alpine

ENV LANG=C.UTF-8

WORKDIR /deployer

ENV PATH=/deployer/bin:$PATH

RUN apk add --no-cache --update curl git

RUN mkdir bin
RUN curl -f https://storage.googleapis.com/kubernetes-release/release/v1.7.3/bin/linux/amd64/kubectl > bin/kubectl && \
    chmod +x bin/kubectl

COPY Gemfile .
COPY Gemfile.lock .
RUN mkdir vendor
COPY vendor/cache vendor/cache
RUN apk add --virtual build-base ruby-dev && \
    bundle install --local && \
    apk del build-base ruby-dev

COPY . .

EXPOSE 8080
CMD ["puma", "-C", "config/puma.rb"]
