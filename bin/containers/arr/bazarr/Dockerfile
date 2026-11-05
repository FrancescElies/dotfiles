FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends git python3 python3-pip python3-venv ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /opt/bazarr
RUN git clone --depth 1 https://github.com/morpheus65535/bazarr.git . && python3 -m venv venv && venv/bin/pip install --no-cache-dir -r requirements.txt
EXPOSE 6767
CMD ["/opt/bazarr/venv/bin/python", "/opt/bazarr/bazarr.py"]