#!/usr/bin/env bash

# Create namespace
kubectl create namespace openftth

# Install Strimzi
helm repo add strimzi https://strimzi.io/charts/
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add jetstack https://charts.jetstack.io

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

# Install Tippecanoe
helm upgrade --install openftth-tilegenerator dax/tippecanoe \
     --namespace openftth \
     --set schedule="*/30 * * * *" \
     --set commandArgs='\
           tippecanoe -z22 --full-detail=10 --low-detail=10 --generate-ids -o /data/route_segments.mbtiles /data/route_segments.geojson --force && \
           tippecanoe -z22 -Bg --full-detail=10 --low-detail=10 --generate-ids -o /data/route_nodes.mbtiles /data/route_nodes.geojson --force'  \
     --set storage.enabled=true \
     --set gdal.enabled=true \
     --set gdal.commandArgs='\
           ogr2ogr -f GeoJSON /data/route_segments.geojson PG:"host=openftth-postgis dbname=OPEN_FTTH user=postgres password=postgres" \
                   -sql "select mrid\, ST_Transform(coord\, 4326) as wkb_geometry from route_network.route_segment WHERE route_network.route_segment.marked_to_be_deleted = false" && \
           ogr2ogr -f GeoJSON /data/route_nodes.geojson PG:"host=openftth-postgis dbname=OPEN_FTTH user=postgres password=postgres" \
                   -sql "select mrid\, ST_Transform(coord\, 4326) as wkb_geometry from route_network.route_node WHERE route_network.route_node.marked_to_be_deleted = false"'

# Install Mbtileserver
helm upgrade --install openftth-tileserver dax/mbtileserver \
  --namespace openftth \
  --set storage.claimName=openftth-tilegenerator-tippecanoe \
  --set image.repository=maptiler/tileserver-gl
  --set service.type=ClusterIP \
  --set 'commandArgs={-v, -d, /data}'

# Install Nginx-Ingress
helm install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace openftth \
    --set controller.replicaCount=1
