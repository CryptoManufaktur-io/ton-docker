# Overview

Docker Compose for TON (The Open Network) liteserver nodes.

`cp default.env .env`, then `nano .env` and adjust values for the right network (mainnet/testnet), particularly `GLOBAL_CONFIG_URL` and `SNAPSHOT`.

Meant to be used with [central-proxy-docker](https://github.com/CryptoManufaktur-io/central-proxy-docker) for traefik and Prometheus remote write; use `:ext-network.yml` in `COMPOSE_FILE` inside `.env` in that case.

`./ethd install` brings in docker-ce, if you don't have Docker installed already.

`cp default.env .env`

`nano .env` and adjust variables, particularly `GLOBAL_CONFIG_URL` and `SNAPSHOT`

`./ethd up`

To update the software, run `./ethd update` and then `./ethd up`

Initial sync: ~10 hours (~4-5 hours with snapshot).

# Configuration

## Mainnet

Basic setup:
```properties
TON_BRANCH=mainnet
GLOBAL_CONFIG_URL=https://ton.org/global.config.json
SNAPSHOT=latest
```

With HTTP API (Traefik):
```properties
COMPOSE_FILE=ton.yml:ton-http-api.yml
```

With HTTP API (direct port):
```properties
COMPOSE_FILE=ton.yml:ton-http-api.yml:ton-http-api-shared.yml
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

Public IP auto-detected on startup. Override with `PUBLIC_IP` in `.env` if needed.

# Customization

Use `custom.yml` to override any settings (not tracked by git). Add to `COMPOSE_FILE` in `.env`.

See `default.env` for all options.

## Version

This is TON Docker v1.0.0
