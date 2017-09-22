FROM ruby:2.4.2

ENV LANG=C.UTF-8

WORKDIR /deployer

ENV PATH=/deployer/bin:$PATH

RUN curl -f -O https://storage.googleapis.com/kubernetes-release/release/v1.7.3/bin/linux/amd64/kubectl
RUN chmod +x kubectl
RUN mkdir bin
RUN mv kubectl bin/kubectl

COPY Gemfile .
COPY Gemfile.lock .
RUN mkdir vendor
COPY vendor/cache vendor/cache
RUN bundle install --local

COPY . .

EXPOSE 8080
CMD ["puma", "-C", "config/puma.rb"]
