#!/usr/bin/env bash
set -euo pipefail
# git pull
rsync -e 'ssh -J root@192.168.192.51' -av --delete --exclude='.git' \
  --exclude='.git' \
  --exclude='venv/' \
  --exclude='__pycache__/' \
  --exclude='*.pyc' \
  ./ root@10.99.99.4:~/Peering_internet_lab/