#!/usr/bin/env bash
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is not installed on the Platform EC2 host."
  exit 1
fi

sudo systemctl enable --now docker

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 is not available."
  exit 1
fi

sudo mkdir -p /var/jenkins_home
sudo chown -R 1000:1000 /var/jenkins_home
sudo chmod 700 /var/jenkins_home

DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"

cat > .env <<ENV
JENKINS_PORT=8080
JENKINS_AGENT_PORT=50000
DOCKER_GID=${DOCKER_GID}
ENV

chmod 600 .env

docker compose config --quiet
docker compose up -d --build

echo
echo "Jenkins started."
echo "Open: http://<PLATFORM_EC2_PUBLIC_IP>:8080"
echo
echo "Initial password (only for a brand-new Jenkins home):"
docker exec platform-jenkins sh -lc 'test -f /var/jenkins_home/secrets/initialAdminPassword && cat /var/jenkins_home/secrets/initialAdminPassword || true'
