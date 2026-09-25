#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_dir"

command -v docker >/dev/null || {
  echo "Docker is not installed. Follow README.md before continuing." >&2
  exit 1
}
docker compose version >/dev/null || {
  echo "Docker Compose v2 is required." >&2
  exit 1
}

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example. Review the network values if this is not the original setup."
fi

mkdir -p data
docker compose pull
docker compose up -d
docker compose ps

