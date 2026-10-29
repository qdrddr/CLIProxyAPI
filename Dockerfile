FROM golang:1.26-bookworm AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends build-essential git && rm -rf /var/lib/apt/lists/*

COPY go.mod go.sum ./

RUN go mod download

COPY . .

ARG VERSION=dev
ARG COMMIT=none
ARG BUILD_DATE=unknown

RUN CGO_ENABLED=1 GOOS=linux go build -buildvcs=false -ldflags="-s -w -X 'main.Version=${VERSION}' -X 'main.Commit=${COMMIT}' -X 'main.BuildDate=${BUILD_DATE}'" -o ./CLIProxyAPI ./cmd/server/

FROM debian:bookworm

ARG NONO_VERSION=0.80.0
ARG TARGETARCH

RUN apt-get update && apt-get install -y --no-install-recommends tzdata ca-certificates wget \
  && wget -q "https://github.com/nolabs-ai/nono/releases/download/v${NONO_VERSION}/nono-cli_${NONO_VERSION}_${TARGETARCH}.deb" \
  && dpkg -i "nono-cli_${NONO_VERSION}_${TARGETARCH}.deb" \
  && rm -f "nono-cli_${NONO_VERSION}_${TARGETARCH}.deb" \
  && apt-get purge -y wget \
  && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/*

ENV HOME=/root

RUN mkdir -p /root/.config/nono/profiles \
  && nono pull nolabs-ai/claude

COPY docker/nono/profiles/claude.json /root/.config/nono/profiles/claude.json

RUN mkdir /CLIProxyAPI

COPY --from=builder ./app/CLIProxyAPI /CLIProxyAPI/CLIProxyAPI

COPY config.example.yaml /CLIProxyAPI/config.example.yaml

WORKDIR /CLIProxyAPI

EXPOSE 8317

ENV TZ=Asia/Shanghai

RUN cp /usr/share/zoneinfo/${TZ} /etc/localtime && echo "${TZ}" > /etc/timezone

COPY docker/nono/nono-entrypoint.sh /usr/local/bin/nono-entrypoint.sh
RUN chmod +x /usr/local/bin/nono-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/nono-entrypoint.sh"]
CMD ["./CLIProxyAPI"]
