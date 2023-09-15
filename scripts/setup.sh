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
    --version 4.7.1 \
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
     --version 16.0.0 \
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
     --set service.type=NodePort

# Install Desktop Bridge.
helm upgrade --install desktop-bridge dax/desktop-bridge \
     --namespace openftth \
     --version 1.0.0

# Install user edit history
helm upgrade --install user-edit-history dax/user-edit-history \
     --version 1.1.1 \
     --namespace openftth \
     --set appsettings.settings.eventStoreConnectionString="Host=openftth-event-store-postgresql;Port=5432;Username=postgres;Password=postgres;Database=EVENT_STORE" \
     --set appsettings.settings.connectionString="Host=openftth-postgis;Port=5432;Username=postgres;Password=postgres;Database=OPEN_FTTH"

# Install notification server
helm upgrade --install notification-server dax/notification-server \
     --version 1.0.1 \
     --namespace openftth

# Install OpenFTTH
helm upgrade --install openftth openftth -n openftth \
     --set-file frontend.maplibreJson=./settings/maplibre.json

# Install Route network validator
helm upgrade --install route-network-validator dax/route-network-validator \
     --version 1.2.0 \
     --namespace openftth \
     --set postgis.database=OPEN_FTTH \
     --set postgis.username=postgres \
     --set postgis.password=postgres \
     --set eventStore.connectionString="Host=openftth-event-store-postgresql;Port=5432;Username=postgres;Password=postgres;Database=EVENT_STORE"

# Install go-http-file-server
helm upgrade --install file-server dax/go-http-file-server \
  --version 5.0.4 \
  --namespace openftth \
  --set commandLineArgs="-l 80 -r /data --global-auth --user user1:pass1 --hostname file-server-go-http-file-server --hostname files.openftth.local --global-delete --global-mkdir --global-upload -L -"

# Install Mbtileserver route-network
helm upgrade --install routenetwork-tileserver dax/mbtileserver \
  --version 5.5.1 \
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
  --version 5.5.1 \
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
  --version 5.5.1 \
  --namespace openftth \
  --set image.tag=danish-1689934495 \
  --set watcher.enabled=false \
  --set 'commandArgs={--enable-fs-watch, -d, /static_tiles}'

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
     --version 1.2.0 \
     --namespace openftth \
     --set schedule="0 0 * * *" \
     --set connectionString="Host=openftth-postgis;Port=5432;Username=postgres;Password=postgres;Database=OPEN_FTTH" \
     --set typesense.host="openftth-search-typesense" \
     --set typesense.apiKey=changeMe!

# Install Route-network-search-indexer
helm upgrade --install route-network-search-indexer dax/route-network-search-indexer \
     --version 2.1.2 \
     --namespace openftth \
     --set eventStore.connectionString="Host=openftth-postgis;Port=5432;Username=postgres;Password=postgres;Database=OPEN_FTTH" \
     --set typesense.apiKey=changeMe!

# Install relational projector
helm upgrade --install relational-projector dax/relational-projector \
     --version 1.1.19 \
     --namespace openftth \
     --set eventStoreDatabase.username=postgres \
     --set eventStoreDatabase.password=postgres \
     --set geoDatabase.username=postgres \
     --set geoDatabase.username=postgres

# Route network tile data extract
helm upgrade --install route-network-tile-data-extract dax/tile-data-extract \
     -f scripts/route-network-tile-data-extract.yaml \
     --version 1.1.0 \
     --namespace openftth

# Access address tile data extract
helm upgrade --install access-address-tile-data-extract dax/tile-data-extract \
     -f scripts/access-address-tile-data-extract.yaml \
     --set schedule="0 1 * * *" \
     --version 1.1.0 \
     --namespace openftth

## Equipment search indexer
helm upgrade --install equipment-search-indexer dax/equipment-search-indexer \
     --version 1.3.13 \
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

## Desktop bridge ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: desktop-bridge-ingress
  namespace: openftth
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
spec:
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
