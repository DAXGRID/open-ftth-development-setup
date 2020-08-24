#!/bin/bash

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path"

POSTGRES_HOST=$1
POSTGRES_PORT=$(kubectl describe service openftth-postgis -n openftth | grep NodePort | grep -o '[0-9]\+')
POSTGRES_DATABASE="OPEN_FTTH"
POSTGRES_USERNAME="postgres"
POSTGRES_PASSWORD="postgres"

sql="$(cat truncate_tables.sql)"

# If psql is not installed, then exit
if ! command -v psql > /dev/null; then
  echo "PostgreSQL is required..."
  exit 1
fi

PGPASSWORD="$POSTGRES_PASSWORD" psql -t -A \
-h "$POSTGRES_HOST" \
-p "$POSTGRES_PORT" \
-d "$POSTGRES_DATABASE" \
-U "$POSTGRES_USERNAME" \
-c "$sql"

kubectl delete kafkatopic event.route-network -n openftth
kubectl apply -f ./event-routenetwork-topic.yaml -n openftth
