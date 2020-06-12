#!/usr/bin/env bash
set -euo pipefail

echo "Setup development environment for OPEN-FTTH"

./setup.sh

echo "Exposes resources for development"
# kubectl expose pod openftth-cassandra-0 --type=NodePort -n openftth
