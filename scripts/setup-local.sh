#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

command -v docker >/dev/null || { echo 'Docker is required.' >&2; exit 1; }
docker compose version >/dev/null
mkdir -p dags logs config plugins

if [[ ! -e .env ]]; then
  # Generate secrets inside the pinned image; no host Python packages required.
  fernet_key="$(docker run --rm --entrypoint python apache/airflow:3.3.2 \
    -c 'from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())')"
  airflow_uid="$(id -u)"
  if [[ "$(uname -s)" != Linux ]]; then
    airflow_uid=50000
  fi
  (umask 077; printf 'AIRFLOW_UID=%s\nFERNET_KEY=%s\n' "$airflow_uid" "$fernet_key" > .env)
  echo 'Created .env with a persistent Fernet key.'
else
  echo 'Using existing .env; credentials were preserved.'
fi

docker compose config --quiet
echo 'Setup ready. Run: docker compose build'
echo 'Then: docker compose up airflow-init'
echo 'Then: docker compose up -d --wait'
