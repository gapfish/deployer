FROM quay.io/gapfish/ruby as builder

RUN apt-get update && apt-get install -y build-essential curl

RUN curl -f https://storage.googleapis.com/kubernetes-release/release/v1.15.0/bin/linux/amd64/kubectl > bin/kubectl && \
  chmod +x bin/kubectl

COPY Gemfile .
COPY Gemfile.lock .
RUN mkdir vendor
COPY vendor/cache vendor/cache
RUN bundle install --local


FROM quay.io/gapfish/ruby

WORKDIR /deployer
ENV PATH=/deployer/bin:$PATH

RUN apt-get update && apt-get install -y \
  git && \
  rm -rf /var/lib/apt/lists/*

RUN mkdir bin
COPY --from=builder bin/kubectl bin/kubectl

COPY --from=builder /var/lib/gems/2.7.0 /var/lib/gems/2.7.0
COPY --from=builder /usr/local/bin /usr/local/bin
COPY . .

EXPOSE 8080
CMD ["puma", "-C", "config/puma.rb"]
