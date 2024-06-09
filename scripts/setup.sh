#!/usr/bin/env bash

set -e

# Create namespace if it does not already exist
kubectl create namespace openftth --dry-run=client -o yaml | kubectl apply -f -

# Register helm repos.
helm repo add bitnami --force-update https://raw.githubusercontent.com/bitnami/charts/archive-full-index/bitnami
helm repo add ingress-nginx --force-update https://kubernetes.github.io/ingress-nginx
helm repo add dax --force-update https://daxgrid.github.io/charts

# Update repos
helm repo update

# Install Nginx-Ingress
kubectl create namespace nginx-ingress --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install nginx-ingress ingress-nginx/ingress-nginx \
    --version 4.10.0 \
    --namespace nginx-ingress \
    --set controller.ingressClassResource.default=true \
    --set controller.replicaCount=1

# We sleep 1 min to make sure that nginx ingress is up and running.
# Otherwise we might experience issues with upgrading since they create
# custom resource definitions.
printf "Sleeping for 1 min waiting for nginx ingress."
sleep 1m

# Install Keycloak
## If there is already a password, we use that one instead.
## It might log an error telling that the key is missing, that is no issue.
ADMIN_PASSWORD=$(kubectl get secret --namespace "openftth" keycloak -o jsonpath="{.data.admin-password}" | base64 --decode)

## Set default password if '$ADMIN_PASSWORD' is empty.
if test -z "$ADMIN_PASSWORD"
then
    ADMIN_PASSWORD="pleaseChangeMe!"
fi

## Disable readiness and liveness probe until we migrate away from /auth
helm upgrade --install keycloak bitnami/keycloak -n openftth \
     --version 21.1.3 \
     --set service.type=ClusterIP \
     --set auth.adminPassword=$ADMIN_PASSWORD \
     --set production=true \
     --set proxy=edge \
     --set httpRelativePath="/auth" \
     --set readinessProbe.enabled=false \
     --set livenessProbe.enabled=false

# Install Postgres database for OpenFTTH eventstore
# Username and password should be changed in live env.
helm upgrade --install openftth-event-store bitnami/postgresql \
     --version 10.3.18 \
     --namespace openftth \
     --set global.postgresql.postgresqlDatabase=EVENT_STORE \
     --set global.postgresql.postgresqlUsername=postgres \
     --set global.postgresql.postgresqlPassword=postgres \
     --set service.type=LoadBalancer

# Install Postgis
# Username and password should be changed in live env.
helm upgrade --install openftth-postgis dax/postgis \
     --version 2.0.0 \
     --set serviceType="LoadBalancer" \
     --set username="postgres" \
     --set password="postgres" \
     --namespace openftth

# Install Desktop Bridge.
helm upgrade --install desktop-bridge dax/desktop-bridge \
     --namespace openftth \
     --version 1.0.2

# Install user edit history
helm upgrade --install user-edit-history dax/user-edit-history \
     --version 1.1.2 \
     --namespace openftth \
     --set appsettings.settings.eventStoreConnectionString="Host=openftth-event-store-postgresql;Port=5432;Username=postgres;Password=postgres;Database=EVENT_STORE" \
     --set appsettings.settings.connectionString="Host=openftth-postgis;Port=5432;Username=postgres;Password=postgres;Database=OPEN_FTTH"

# Install notification server
helm upgrade --install notification-server dax/notification-server \
     --version 1.0.2 \
     --namespace openftth

# Install OpenFTTH api gateway
helm upgrade --install openftth-api-gateway dax/openftth-api-gateway \
     -f scripts/openftth-api-gateway-override.yaml \
     --version 1.1.15 \
     --namespace openftth

# Install OpenFTTH frontend
helm upgrade --install openftth-frontend dax/openftth-frontend \
    -f scripts/openftth-frontend-override.yaml \
    --version 1.2.4 \
    --namespace openftth \
    --set-file maplibreJson=./settings/maplibre.json

# Install Route network validator
helm upgrade --install route-network-validator dax/route-network-validator \
     --version 1.2.2 \
     --namespace openftth \
     --set postgis.database=OPEN_FTTH \
     --set postgis.username=postgres \
     --set postgis.password=postgres \
     --set eventStore.connectionString="Host=openftth-event-store-postgresql;Port=5432;Username=postgres;Password=postgres;Database=EVENT_STORE"

# Install go-http-file-server
helm upgrade --install file-server dax/go-http-file-server \
  --version 5.0.10 \
  --namespace openftth \
  --set commandLineArgs="-l 80 -r /data --global-auth --user user1:pass1 --hostname file-server-go-http-file-server --hostname files.openftth.local --global-delete --global-mkdir --global-upload -L -"

# Install Mbtileserver route-network
helm upgrade --install routenetwork-tileserver dax/mbtileserver \
  --version 5.6.1 \
  --namespace openftth \
  --set watcher.enabled=true \
  --set watcher.fileServer.username=user1 \
  --set watcher.fileServer.password=pass1 \
  --set watcher.fileServer.uri=http://file-server-go-http-file-server \
  --set "watcher.tileProcess.processes[0].name=TILEPROCESS__PROCESS__route_network.geojson" \
  --set "watcher.tileProcess.processes[0].value=-z17 -pS -P -o /tmp/route_network.mbtiles /tmp/route_network.geojson --force --quiet" \
  --set 'commandArgs={--enable-fs-watch, --tiles-only, -d, /data}'

# Install Mbtileserver access-address
helm upgrade --install access-address-tileserver dax/mbtileserver \
  --version 5.6.1 \
  --namespace openftth \
  --set watcher.enabled=true \
  --set watcher.fileServer.username=user1 \
  --set watcher.fileServer.password=pass1 \
  --set watcher.fileServer.uri=http://file-server-go-http-file-server \
  --set "watcher.tileProcess.processes[0].name=TILEPROCESS__PROCESS__access_address.geojson" \
  --set "watcher.tileProcess.processes[0].value=-z17 -pS -P -o /tmp/access_address.mbtiles /tmp/access_address.geojson --force --quiet" \
  --set watcher.startupProbe.failureThreshold=200 \
  --set 'commandArgs={--enable-fs-watch, --tiles-only, -d, /data}'

# Install Mbtileserver base-map
helm upgrade --install basemap-tileserver dax/mbtileserver \
  --version 5.6.1 \
  --namespace openftth \
  --set image.tag=danish-1698762103 \
  --set watcher.enabled=false \
  --set 'commandArgs={--enable-fs-watch, -d, /static_tiles}'

# Install Typesense
helm upgrade --install openftth-search dax/typesense \
  --version 1.2.1 \
  --namespace openftth \
  --set serviceType=ClusterIP \
  --set apiKey=changeMe! \
  --set resources.memoryRequest="2Gi" \
  --set resources.memoryLimit="3Gi"

# Install Address import DAWA.
helm upgrade --install address-import-dawa dax/address-import-dawa \
     --version 1.2.4 \
     --namespace openftth \
     --set appsettings.settings.eventStoreConnectionString="Host=openftth-event-store-postgresql;Port=5432;Username=postgres;Password=postgres;Database=EVENT_STORE"

# Install Address postgis projector
helm upgrade --install address-postgis-projector dax/address-postgis-projector \
     --version 1.0.11 \
     --namespace openftth \
     --set appsettings.settings.eventStoreConnectionString="Host=openftth-event-store-postgresql;Port=5432;Username=postgres;Password=postgres;Database=EVENT_STORE" \
     --set appsettings.settings.postgisConnectionString="Host=openftth-postgis;Port=5432;Username=postgres;Password=postgres;Database=OPEN_FTTH"

# Install access address search indexer
helm upgrade --install address-search-indexer dax/address-search-indexer \
     --version 1.1.11 \
     --namespace openftth \
     --set appsettings.settings.eventStoreConnectionString="Host=openftth-event-store-postgresql;Port=5432;Username=postgres;Password=postgres;Database=EVENT_STORE" \
     --set appsettings.settings.typesense.key="changeMe!"

# Install Route-network-search-indexer
helm upgrade --install route-network-search-indexer dax/route-network-search-indexer \
     --version 2.2.3 \
     --namespace openftth \
     --set eventStore.connectionString="Host=openftth-postgis;Port=5432;Username=postgres;Password=postgres;Database=OPEN_FTTH" \
     --set typesense.apiKey=changeMe!

# Install relational projector
helm upgrade --install relational-projector dax/relational-projector \
     --version 1.2.4 \
     --namespace openftth \
     --set eventStoreDatabase.username=postgres \
     --set eventStoreDatabase.password=postgres \
     --set geoDatabase.username=postgres \
     --set geoDatabase.username=postgres

# Route network tile data extract
helm upgrade --install route-network-tile-data-extract dax/tile-data-extract \
     -f scripts/route-network-tile-data-extract.yaml \
     --version 1.1.6 \
     --namespace openftth

# Access address tile data extract
helm upgrade --install access-address-tile-data-extract dax/tile-data-extract \
     -f scripts/access-address-tile-data-extract.yaml \
     --set schedule="0 1 * * *" \
     --version 1.1.6 \
     --namespace openftth

# GDB-Integrator
helm upgrade --install gdb-integrator dax/gdb-integrator \
     --version 1.0.4 \
     --namespace openftth \
     --set eventStore.connectionString="Host=openftth-event-store-postgresql;Port=5432;Username=postgres;Password=postgres;Database=EVENT_STORE"

## Equipment search indexer
helm upgrade --install equipment-search-indexer dax/equipment-search-indexer \
     --version 1.3.14 \
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
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-body-size: 25m
spec:
  ingressClassName: nginx
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

## Desktop bridge ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: desktop-bridge-ingress
  namespace: openftth
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
spec:
  ingressClassName: nginx
  rules:
  - host: desktop-bridge.openftth.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: desktop-bridge
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
spec:
  ingressClassName: nginx
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
spec:
  ingressClassName: nginx
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
spec:
  ingressClassName: nginx
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

## OpenFTTH frontend ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: frontend-ingress
  namespace: openftth
spec:
  ingressClassName: nginx
  rules:
  - host: openftth.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: openftth-frontend
            port:
              number: 80
EOF

## OpenFTTH api-gateway ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway-ingress
  namespace: openftth
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
spec:
  ingressClassName: nginx
  rules:
  - host: api-gateway.openftth.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: openftth-api-gateway
            port:
              number: 80
EOF

## Kecloak Ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak-ingress
  namespace: openftth
spec:
  ingressClassName: nginx
  rules:
  - host: auth.openftth.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak
            port:
              number: 80
EOF
