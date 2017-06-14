FROM ruby:2.4.0-slim
RUN apt-get update && apt-get install -y git
COPY depctl/bin/depctl.rb /usr/local/bin/
COPY depctl/lib/trollop.rb /usr/local/lib/
COPY lib/shared/version.rb /usr/local/lib/
RUN mkdir -p .git/refs/heads
COPY .git/HEAD /usr/.git/
COPY .git/refs/heads /usr/.git/refs/heads
ENTRYPOINT ["depctl.rb"]
CMD []
