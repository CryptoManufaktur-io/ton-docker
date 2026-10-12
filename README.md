# Overview

Docker Compose for ton

Meant to be used with [central-proxy-docker](https://github.com/CryptoManufaktur-io/central-proxy-docker) for traefik
and Prometheus remote write; use `:ext-network.yml` in `COMPOSE_FILE` inside `.env` in that case.

If you want the RPC ports exposed locally, use `rpc-shared.yml` in `COMPOSE_FILE` inside `.env`.

## Quick Start

The `./tond` script can be used as a quick-start:

`./tond install` brings in docker-ce, if you don't have Docker installed already.

`cp default.env .env`

`nano .env` and adjust variables as needed, particularly mention-important-vars-here

`./tond up`

## Metrics

`validator-engine` has a native Prometheus exporter, enabled by the entrypoint via `--exporter-address` and served
at `/metrics` on `METRICS_PORT` (default 9102, container-internal, not published). The `ton` service carries
`metrics.*` labels so the Prometheus from `central-proxy-docker` scrapes it when `ext-network.yml` is in
`COMPOSE_FILE`. Set `METRICS_ENABLE=false` to disable. Metric names start with `ton_`, see
[METRICS.md](https://github.com/ton-blockchain/ton/blob/master/metrics/METRICS.md) upstream.

`ton-http-api` has no Prometheus metrics.

## Software update

To update the software, run `./tond update` and then `./tond up`

## Customization

`custom.yml` is not tracked by git and can be used to override anything in the provided yml files. If you use it,
add it to `COMPOSE_FILE` in `.env`

## Version

ton Docker uses a semver scheme.

This is ton Docker v1.0.0
