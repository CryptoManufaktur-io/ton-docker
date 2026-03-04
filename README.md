# Overview

Docker Compose for TON (The Open Network) nodes running as liteservers

`cp default.env .env`, adjust values, and `./ethd up`

Meant to be used with [central-proxy-docker](https://github.com/CryptoManufaktur-io/central-proxy-docker) for traefik and Prometheus remote write; use `:ext-network.yml` in `COMPOSE_FILE` inside `.env` in that case.

**Local RPC access:** Add `ton-shared.yml` to `COMPOSE_FILE` in `.env` to expose liteserver and validator console ports locally instead of via traefik.

## Quick Start

`./ethd install` to install docker-ce, if you don't have Docker installed already.

`cp default.env .env` and adjust variables, particularly `GLOBAL_CONFIG_URL` (mainnet/testnet) and `SNAPSHOT` (faster sync).

`./ethd up`

Initial sync takes ~10 hours (or ~4-5 hours with snapshot).

## Optional Features

### HTTP API

Enable HTTP/JSON-RPC API for monitoring and integration:

```properties
COMPOSE_FILE=ton.yml:ton-http-api.yml
TON_API_HTTP_PORT=8081
```

The HTTP API provides endpoints for querying TON blockchain data via HTTP and JSON-RPC.

## Mainnet Configuration

Basic setup in `.env`:

```properties
TON_BRANCH=mainnet
GLOBAL_CONFIG_URL=https://ton.org/global.config.json
SNAPSHOT=latest
LITESERVER_PORT=30003
VALIDATOR_PORT=30001
```

With HTTP API:

```properties
COMPOSE_FILE=ton.yml:ton-http-api.yml
TON_BRANCH=mainnet
GLOBAL_CONFIG_URL=https://ton.org/global.config.json
SNAPSHOT=latest
```

With local RPC access:

```properties
COMPOSE_FILE=ton.yml:ton-shared.yml
TON_BRANCH=mainnet
GLOBAL_CONFIG_URL=https://ton.org/global.config.json
SNAPSHOT=latest
```

## Testnet Configuration

Basic testnet setup in `.env`:

```properties
TON_BRANCH=testnet
GLOBAL_CONFIG_URL=https://ton.org/testnet-global.config.json
SNAPSHOT=latest_testnet
LITESERVER_PORT=30003
VALIDATOR_PORT=30001
```

With HTTP API and local RPC:

```properties
COMPOSE_FILE=ton.yml:ton-shared.yml:ton-http-api.yml
TON_BRANCH=testnet
GLOBAL_CONFIG_URL=https://ton.org/testnet-global.config.json
SNAPSHOT=latest_testnet
```

## Operations

### Check Sync Status

```bash
./scripts/check-sync.sh
```

Exit codes: 0=synced, 1=syncing, 2=error

### Monitor Logs

```bash
./ethd logs -f ton
```

### Detailed Status

```bash
docker exec -it ton bash
mytonctrl
MyTonCtrl> status
```

Shows node mode, sync status, system resources, and validator info.

### Test HTTP API

If HTTP API is enabled:

```bash
# masterchain info
curl -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getMasterchainInfo","params":[]}' \
  http://localhost:8081

# health check
curl http://localhost:8081/healthcheck
```

### Liteserver Configuration

After full sync, generate liteserver config for client connections:

```bash
docker exec -it ton mytonctrl
MyTonCtrl> installer clcf
```

Creates `/usr/bin/ton/local.config.json` with public IP, port, public key, and network configuration.

### Software Update

```bash
./ethd update && ./ethd up
```

## Hardware Requirements

**Mainnet:**
- CPU: 16 cores
- RAM: 64 GB
- Storage: 1TB SSD/NVMe (~250GB used, grows over time)
- Network: 1 Gbps, 10TB+ monthly traffic
- OS: Ubuntu 22.04 LTS (recommended)

**Testnet:** Similar requirements, ~100GB storage

## Network and Ports

- Public IP auto-detected on startup (override with `PUBLIC_IP` in `.env` for Kubernetes/special networks)
- Ports auto-generated during first setup
- Requires open firewall for generated ports (UDP + TCP)

Default ports (customizable in `.env`):
- `VALIDATOR_PORT` (30001/udp) - P2P networking (always exposed)
- `LITESERVER_PORT` (30003/tcp) - Liteserver client connections (via traefik or ton-shared.yml)
- `VALIDATOR_CONSOLE_PORT` (30002/tcp) - Validator console (via ton-shared.yml if needed)
- `TON_API_HTTP_PORT` (8081/tcp) - HTTP API (if enabled)

## Traefik / Reverse Proxy Access

Default liteserver access via Traefik labels. Configure in `.env`:

```properties
TON_HOST=ton
DOMAIN=example.com
```

Accessible at TCP port configured in your Traefik entrypoint.

For local port exposure, add `ton-shared.yml` to `COMPOSE_FILE`.

## Customization

`custom.yml` is not tracked by git and can override anything in the provided yml files. Add to `COMPOSE_FILE` in `.env` if used.

## Configuration Reference

See `default.env` for all configuration options, including:
- **Network:** `GLOBAL_CONFIG_URL`, `TON_BRANCH`, `MODE`
- **Snapshot:** `SNAPSHOT` (empty, dump name, or full URL)
- **Performance:** `ARCHIVE_TTL`, `STATE_TTL`, `VERBOSITY`
- **HTTP API:** `TON_API_HTTP_PORT`, `TON_API_LOGS_LEVEL`, `TON_API_WEBSERVERS_WORKERS`

## Version

This is TON Docker v1.0.0
