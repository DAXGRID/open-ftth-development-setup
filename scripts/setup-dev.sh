#!/bin/sh
#
# Setup environment
./scripts/setup.sh

# Create secrets for dev environment

cat <<EOF > debezium-postgres-credentials.properties
username: postgres
password: postgres
EOF
kubectl -n openftth create secret generic postgres-credentials \
  --from-file=debezium-postgres-credentials.properties
rm debezium-postgres-credentials.properties


