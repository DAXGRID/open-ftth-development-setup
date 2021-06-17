#!/usr/bin/env bash

# Create namespace
kubectl create namespace openftth

# Install Strimzi
helm repo add strimzi https://strimzi.io/charts/
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io
helm repo add dax https://daxgrid.github.io/charts

# Update repos
helm repo update

# Install strimzi
helm install strimzi strimzi/strimzi-kafka-operator \
     -n openftth \
     --version 0.19

# Install loki
helm upgrade --install loki \
     grafana/loki-stack \
     --namespace=loki \
     --create-namespace \
     --set grafana.enabled=true \
     --set prometheus.enabled=true \
     --set prometheus.alertmanager.persistentVolume.enabled=false \
     --set prometheus.server.persistentVolume.enabled=false \
     --set loki.persistence.enabled=true \
     --set loki.persistence.storageClassName=standard \
     --set loki.persistence.size=8Gi \
     --version 2.3.1

# Install Keycloak
helm upgrade --install keycloak bitnami/keycloak -n openftth \
     --version 2.3.0 \
     --set service.type=ClusterIP \
     --set proxyAddressForwarding=true

# Install the cert-manager
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.3.1 \
  --set installCRDs=true

# Install Postgres database for OpenFTTH eventstore
# Username and password should be changed in live env.
helm install openftth-event-store bitnami/postgresql \
     --namespace openftth \
     --set global.postgresql.postgresqlDatabase=EVENT_STORE \
     --set global.postgresql.postgresqlUsername=postgres \
     --set global.postgresql.postgresqlPassword=postgres \
     --set service.type=ClusterIP

# Install OpenFTTH
helm install openftth openftth --namespace openftth

# Install Mbtileserver route-network
helm upgrade --install openftth-routenetwork-tileserver dax/mbtileserver \
  --version 3.0.0 \
  --namespace openftth \
  --set service.type=NodePort \
  --set storage.size=1Gi \
  --set 'commandArgs={--enable-reload-signal, --disable-preview, -d, /data}'

# Install Mbtileserver base-map
helm upgrade --install openftth-basemap-tileserver dax/mbtileserver \
  --version 3.0.0 \
  --namespace openftth \
  --set image.tag=danish-1621954230 \
  --set service.type=NodePort \
  --set storage.enabled=false \
  --set 'commandArgs={--enable-reload-signal, -d, /tilesets}' \
  --set reload.enabled=false

# Install Typesense
helm upgrade --install openftth-search dax/typesense \
  --version 1.0.0 \
  --namespace openftth \
  --set serviceType=LoadBalancer \
  --set apiKey=changeMe! \
  --set resources.memoryRequest="2Gi" \
  --set resources.memoryLimit="3Gi"

# Install danish address seed
helm upgrade --install danish-address-seed dax/danish-address-seed \
     --version 1.1.3 \
     --namespace openftth \
     --set schedule="0 0 * * *" \
     --set connectionString="Host=openftth-postgis;Port=5432;Username=postgres;Password=postgres;Database=OPEN_FTTH" \
     --set typesense.host="openftth-search-typesense" \
     --set typesense.apiKey=changeMe!

# Install Tippecanoe
helm upgrade --install openftth-tilegenerator dax/tippecanoe \
     --version 2.0.0 \
     --namespace openftth \
     --set schedule="*/30 * * * *" \
     --set commandArgs='sha1sum --ignore-missing -c /data/route_network.geojson.sha1 || (tippecanoe -z17 -pS -P -o ./route_network.mbtiles /data/route_network.geojson --force && cp ./route_network.mbtiles /data/route_network.mbtiles && sha1sum /data/route_network.geojson > /data/route_network.geojson.sha1)' \
     --set storage.enabled=true \
     --set storage.claimName=openftth-routenetwork-tileserver-mbtileserver \
     --set prejob.enabled=true \
     --set prejob.commandArgs='dotnet OpenFTTH.TileDataExtractor.dll "Host=openftth-postgis;Port=5432;Username=postgres;Password=postgres;Database=OPEN_FTTH" route_network.geojson && cp route_network.geojson /data/route_network.geojson' \
     --set prejob.image.repository=openftth/tile-data-extract \
     --set prejob.image.tag=v1.3.0

# Install Nginx-Ingress
helm install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace openftth \
    --set controller.replicaCount=1
