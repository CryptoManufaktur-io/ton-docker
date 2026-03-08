# Overview

Docker Compose for TON (The Open Network) liteserver nodes.

`cp default.env .env`, adjust values for the right network (mainnet/testnet), then `./ethd up`.

Meant to be used with [central-proxy-docker](https://github.com/CryptoManufaktur-io/central-proxy-docker) for traefik and Prometheus remote write; use `:ext-network.yml` in `COMPOSE_FILE` inside `.env` in that case.

Add `ton-shared.yml` to `COMPOSE_FILE` to expose liteserver and validator console ports locally instead of via traefik.

`./ethd install` brings in docker-ce, if you don't have Docker installed already.

`cp default.env .env`

`nano .env` and adjust variables, particularly `GLOBAL_CONFIG_URL` and `SNAPSHOT`

`./ethd up`

Initial sync: ~10 hours (~4-5 hours with snapshot).

To update the software, run `./ethd update` and then `./ethd up`

# Configuration

## Mainnet

Basic setup:
```properties
TON_BRANCH=mainnet
GLOBAL_CONFIG_URL=https://ton.org/global.config.json
SNAPSHOT=latest
```

With HTTP API:
```properties
COMPOSE_FILE=ton.yml:ton-http-api.yml
TON_API_HTTP_PORT=8081
```

With local RPC access:
```properties
COMPOSE_FILE=ton.yml:ton-shared.yml
```

## Testnet

```properties
TON_BRANCH=testnet
GLOBAL_CONFIG_URL=https://ton.org/testnet-global.config.json
SNAPSHOT=latest_testnet
```

## HTTP API

Enable HTTP/JSON-RPC API in `COMPOSE_FILE`:
```properties
COMPOSE_FILE=ton.yml:ton-http-api.yml
TON_API_HTTP_PORT=8081
```

Test endpoints:
```bash
# masterchain info
curl -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"getMasterchainInfo","params":[]}' \
  http://localhost:8081

# health check
curl http://localhost:8081/healthcheck
```

# Operations

## Check Sync Status
```bash
./scripts/check-sync.sh
```
Exit codes: 0=synced, 1=syncing, 2=error

## Monitor Logs
```bash
./ethd logs -f ton
```

## Node Status
```bash
docker compose exec ton mytonctrl
MyTonCtrl> status
```

## Generate Liteserver Config
After full sync:
```bash
docker compose exec ton mytonctrl
MyTonCtrl> installer clcf
```
Creates `/usr/bin/ton/local.config.json` for client connections.

# Hardware Requirements

**Mainnet:**
- 16 cores, 64GB RAM
- 1TB SSD/NVMe (~250GB used, grows over time)
- 1 Gbps, 10TB+ monthly traffic

**Testnet:** Similar, ~100GB storage

# Ports

Default ports (customizable in `.env`):
- `VALIDATOR_PORT` (30001/udp) - P2P networking
- `LITESERVER_PORT` (30003/tcp) - Liteserver connections
- `VALIDATOR_CONSOLE_PORT` (30002/tcp) - Console access
- `TON_API_HTTP_PORT` (8081/tcp) - HTTP API

Public IP auto-detected on startup. Override with `PUBLIC_IP` in `.env` if needed.

# Customization

`custom.yml` can override any settings and is not tracked by git. Add to `COMPOSE_FILE` in `.env` if used.

See `default.env` for all configuration options.

## Version

This is TON Docker v1.0.0
