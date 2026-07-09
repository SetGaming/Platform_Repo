#!/usr/bin/env bash
set -euo pipefail

echo "== Docker Compose status =="
docker compose ps

echo
echo "== Jenkins health =="
docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' platform-jenkins

echo
echo "== Docker access from Jenkins container =="
docker exec platform-jenkins docker version

echo
echo "== Required plugins =="
docker exec platform-jenkins jenkins-plugin-cli --list \
  | grep -E 'workflow-multibranch|docker-workflow|github-branch-source|ssh-agent|git' || true
