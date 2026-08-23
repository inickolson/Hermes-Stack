FROM python:3.11-slim

WORKDIR /app

RUN apt-get update &&     apt-get install -y --no-install-recommends procps curl tar &&     apt-get clean && rm -rf /var/lib/apt/lists/*

# Download v0.20.0 release source code
RUN curl -L -o /tmp/hermes.tar.gz https://github.com/NousResearch/hermes-agent/archive/refs/tags/v2026.8.3.tar.gz &&     mkdir -p /tmp/hermes-src &&     tar -xzf /tmp/hermes.tar.gz -C /tmp/hermes-src --strip-components=1

# Set env var to bypass installer restriction and install
WORKDIR /tmp/hermes-src
ENV HERMES_NIX_BUILD=1
RUN pip install --no-cache-dir .

RUN pip install --no-cache-dir fastapi uvicorn jinja2 python-multipart
RUN pip install --no-cache-dir mcp

RUN mkdir -p /root/.hermes &&     echo "GATEWAY_ALLOW_ALL_USERS=true" > /root/.hermes/.env &&     echo "HERMES_INSECURE=true" >> /root/.hermes/.env

ENV HERMES_WEB_DIR=/usr/local/lib/python3.11/site-packages/hermes_agent/web/dist

EXPOSE 8020

CMD sh -c "hermes gateway run & sleep 3 && hermes dashboard --host 0.0.0.0 --port 8020 --insecure"
ENV HERMES_NIX_BUILD=1
