FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends qbittorrent-nox && rm -rf /var/lib/apt/lists/*
EXPOSE 8080 6881 6881/udp
CMD ["qbittorrent-nox", "--webui-port=8080"]