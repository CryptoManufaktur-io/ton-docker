FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates bash curl pv plzip tar aria2 \
    && rm -rf /var/lib/apt/lists/*

COPY ./fetch-snapshot.sh /usr/local/bin/fetch-snapshot.sh
RUN chmod 755 /usr/local/bin/fetch-snapshot.sh

ENTRYPOINT ["/usr/local/bin/fetch-snapshot.sh"]
