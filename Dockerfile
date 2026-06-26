FROM ubuntu:latest
RUN apt-get update -qq && apt-get install -y -qq bc && rm -rf /var/lib/apt/lists/*
COPY monitor.sh /monitor.sh
RUN chmod +x /monitor.sh
CMD ["/monitor.sh"]
