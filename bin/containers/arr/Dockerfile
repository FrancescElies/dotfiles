# Build: podman build -t arr-stack .
# 
# Run:   mkdir ~/arr/config ~/arr/data
# Run:   podman run -d --name arr -p 6767:6767 -p 7878:7878 -p 8686:8686 -p 8787:8787 -v ~/arr/config:/config -v ~/arr//data:/data arr-stack
FROM debian:bookworm-slim AS base
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git python3 python3-pip python3-venv \
    libicu-dev libssl-dev zlib1g supervisor qbittorrent-nox && rm -rf /var/lib/apt/lists/*

# .NET SDK for building the *arr apps
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS dotnet-build
WORKDIR /src
RUN git clone --depth 1 https://github.com/Radarr/Radarr.git radarr && \
    git clone --depth 1 https://github.com/Lidarr/Lidarr.git lidarr && \
    git clone --depth 1 https://github.com/Readarr/Readarr.git readarr
RUN dotnet publish /src/radarr/src/NzbDrone.Console/Radarr.Console.csproj -c Release -f net10.0 -o /out/radarr && \
    dotnet publish /src/lidarr/src/NzbDrone.Console/Lidarr.Console.csproj -c Release -f net10.0 -o /out/lidarr && \
    dotnet publish /src/readarr/src/NzbDrone.Console/Readarr.Console.csproj -c Release -f net10.0 -o /out/readarr

# Bazarr (Python) source
FROM base AS bazarr-src
WORKDIR /opt/bazarr
RUN git clone --depth 1 https://github.com/morpheus65535/bazarr.git . && \
    python3 -m venv /opt/bazarr/venv && \
    /opt/bazarr/venv/bin/pip install --no-cache-dir -r requirements.txt

# Final single container
FROM base
RUN curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh && \
    bash /tmp/dotnet-install.sh --channel 10.0 --runtime aspnetcore --install-dir /usr/share/dotnet && \
    ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet && rm /tmp/dotnet-install.sh
COPY --from=dotnet-build /out/radarr /opt/radarr
COPY --from=dotnet-build /out/lidarr /opt/lidarr
COPY --from=dotnet-build /out/readarr /opt/readarr
COPY --from=bazarr-src /opt/bazarr /opt/bazarr

# supervisord config
RUN mkdir -p /var/log/supervisor /config
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY ../vimrc /root/.vimrc

VOLUME ["/config", "/data"]
EXPOSE 6767 7878 8080 8686 8787
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/supervisord.conf"]
