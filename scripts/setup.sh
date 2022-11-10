#!/usr/bin/env bash

set -e

# Create namespace if it does not already exist
kubectl create namespace openftth --dry-run=client -o yaml | kubectl apply -f -

# Install Strimzi
helm repo add strimzi --force-update https://strimzi.io/charts/
helm repo add grafana --force-update https://grafana.github.io/helm-charts
helm repo add bitnami --force-update https://raw.githubusercontent.com/bitnami/charts/archive-full-index/bitnami
helm repo add ingress-nginx --force-update https://kubernetes.github.io/ingress-nginx
helm repo add dax --force-update https://daxgrid.github.io/charts

# Update repos
helm repo update

# Install strimzi
helm upgrade --install strimzi strimzi/strimzi-kafka-operator \
     -n openftth \
     --version 0.26.1

# Install Nginx-Ingress
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
    --version 4.0.16 \
    --namespace nginx-ingress \
    --set controller.ingressClassResource.default=true \
    --set controller.replicaCount=1

# We sleep 1 min to make sure that nginx ingress and strimzi is up and running.
# Otherwise we might experience issues with upgrading since they create
# custom resource definitions.
printf "Sleeping for 1 min waiting for nginx ingress and strimzi."
sleep 1m

# Install Keycloak

## If there is already a password, we use that one instead.
ADMIN_PASSWORD=$(kubectl get secret --namespace "openftth" keycloak -o jsonpath="{.data.admin-password}" | base64 --decode)

## Set default password if '$ADMIN_PASSWORD' is empty.
if test -z "$ADMIN_PASSWORD"
then
    ADMIN_PASSWORD="pleaseChangeMe!"
fi

helm upgrade --install keycloak bitnami/keycloak -n openftth \
     --version 2.3.0 \
     --set service.type=ClusterIP \
     --set auth.adminPassword=$ADMIN_PASSWORD \
     --set proxyAddressForwarding=true

# Install Postgres database for OpenFTTH eventstore
# Username and password should be changed in live env.
helm upgrade --install openftth-event-store bitnami/postgresql \
     --version 10.3.18 \
     --namespace openftth \
     --set global.postgresql.postgresqlDatabase=EVENT_STORE \
     --set global.postgresql.postgresqlUsername=postgres \
     --set global.postgresql.postgresqlPassword=postgres \
     --set service.type=NodePort

# Install OpenFTTH
helm upgrade --install openftth openftth -n openftth \
     --set-file frontend.maplibreJson=./settings/maplibre.json

# Install go-http-file-server
helm upgrade --install file-server dax/go-http-file-server \
  --version 2.2.0 \
  --namespace openftth \
  --set username=user1 \
  --set password=pass1

# Install Mbtileserver route-network
helm upgrade --install routenetwork-tileserver dax/mbtileserver \
  --version 4.2.0 \
  --namespace openftth \
  --set watcher.enabled=true \
  --set watcher.fileServer.username=user1 \
  --set watcher.fileServer.password=pass1 \
  --set watcher.fileServer.uri=http://file-server-go-http-file-server \
  --set watcher.kafka.consumer=tile_watcher_route_network \
  --set watcher.kafka.server=openftth-kafka-cluster-kafka-bootstrap:9092 \
  --set "watcher.tileProcess.processes[0].name=TILEPROCESS__PROCESS__route_network.geojson" \
  --set "watcher.tileProcess.processes[0].value=-z17 -pS -P -o /tmp/route_network.mbtiles /tmp/route_network.geojson --force --quiet" \
  --set 'commandArgs={--enable-reload-signal, --disable-preview, -d, /data}'

# Install Mbtileserver access-address
helm upgrade --install access-address-tileserver dax/mbtileserver \
  --version 4.2.0 \
  --namespace openftth \
  --set watcher.enabled=true \
  --set watcher.fileServer.username=user1 \
  --set watcher.fileServer.password=pass1 \
  --set watcher.fileServer.uri=http://file-server-go-http-file-server \
  --set watcher.kafka.consumer=tile_watcher_access_address \
  --set watcher.kafka.server=openftth-kafka-cluster-kafka-bootstrap:9092 \
  --set "watcher.tileProcess.processes[0].name=TILEPROCESS__PROCESS__access_address.geojson" \
  --set "watcher.tileProcess.processes[0].value=-z17 -pS -P -o /tmp/access_address.mbtiles /tmp/access_address.geojson --force --quiet" \
  --set 'commandArgs={--enable-reload-signal, --disable-preview, -d, /data}'

# Install Mbtileserver base-map
helm upgrade --install basemap-tileserver dax/mbtileserver \
  --version 4.2.0 \
  --namespace openftth \
  --set image.tag=danish-1621954230 \
  --set 'commandArgs={--enable-reload-signal, --disable-preview, -d, /tilesets}'

# Install Typesense
helm upgrade --install openftth-search dax/typesense \
  --version 1.0.0 \
  --namespace openftth \
  --set serviceType=ClusterIP \
  --set apiKey=changeMe! \
  --set resources.memoryRequest="2Gi" \
  --set resources.memoryLimit="3Gi"

# Install Danish-address-seed
helm upgrade --install danish-address-seed dax/danish-address-seed \
     --version 1.1.16 \
     --namespace openftth \
     --set schedule="0 0 * * *" \
     --set connectionString="Host=openftth-postgis;Port=5432;Username=postgres;Password=postgres;Database=OPEN_FTTH" \
     --set typesense.host="openftth-search-typesense" \
     --set typesense.apiKey=changeMe!

# Install Route-network-search-indexer
helm upgrade --install route-network-search-indexer dax/route-network-search-indexer \
     --version 1.3.1 \
     --namespace openftth \
     --set kafka.positionConnectionString="Host=openftth-postgis;Port=5432;Username=postgres;Password=postgres;Database=OPEN_FTTH" \
     --set typesense.apiKey=changeMe!

# Install relational projector
helm upgrade --install relational-projector dax/relational-projector \
     --version 1.1.11 \
     --namespace openftth \
     --set eventStoreDatabase.username=postgres \
     --set eventStoreDatabase.password=postgres \
     --set geoDatabase.username=postgres \
     --set geoDatabase.username=postgres

# Route network tile data extract
helm upgrade --install route-network-tile-data-extract dax/tile-data-extract \
     -f scripts/route-network-tile-data-extract.yaml \
     --version 1.0.6 \
     --namespace openftth

# Access address tile data extract
helm upgrade --install access-address-tile-data-extract dax/tile-data-extract \
     -f scripts/access-address-tile-data-extract.yaml \
     --set schedule="0 1 * * *" \
     --version 1.0.6 \
     --namespace openftth

## Equipment search indexer
helm upgrade --install equipment-search-indexer dax/equipment-search-indexer \
     --version 1.3.10 \
     --namespace openftth \
     --set "specifications[0]"=Kundeterminering \
     --set connectionstring="Host=openftth-event-store-postgresql;Port=5432;Username=postgres;Password=postgres;Database=EVENT_STORE" \
     --set typesense.apiKey="changeMe\!"

# Setup ingress resources

## File server ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: file-server-ingress
  namespace: openftth
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-body-size: 25m
spec:
  rules:
  - host: files.openftth.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: file-server-go-http-file-server
            port:
              number: 80
EOF

## Routenetwork tileserver ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: routenetwork-tileserver-ingress
  namespace: openftth
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: tiles-routenetwork.openftth.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: routenetwork-tileserver-mbtileserver
            port:
              number: 80
EOF

## Access address tileserver ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: access-address-tileserver-ingress
  namespace: openftth
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: tiles-access-address.openftth.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: access-address-tileserver-mbtileserver
            port:
              number: 80
EOF

## Basemap tileserver ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: basemap-tileserver-ingress
  namespace: openftth
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: tiles-basemap.openftth.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: basemap-tileserver-mbtileserver
            port:
              number: 80
EOF
