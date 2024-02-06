#!/usr/bin/env bash
set -e

## starting pgbouncer
/usr/bin/pgbouncer /etc/pgbouncer/pgbouncer.ini 2>&1