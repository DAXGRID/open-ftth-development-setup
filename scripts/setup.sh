#!/usr/bin/env bash

# Create namespace
kubectl create namespace openftth

# Install Strimzi
helm repo add strimzi https://strimzi.io/charts/
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add dax https://daxgrid.github.io/charts

# Update repos
helm repo update

# Install strimzi
helm upgrade --install strimzi strimzi/strimzi-kafka-operator \
     -n openftth \
     --version 0.25.0

# Install Nginx-Ingress
helm install nginx-ingress ingress-nginx/ingress-nginx \
    --version 3.23.0 \
    --namespace nginx-ingress \
    --create-namespace \
    --set controller.replicaCount=1

# Install Keycloak
helm upgrade --install keycloak bitnami/keycloak -n openftth \
     --version 2.3.0 \
     --set service.type=ClusterIP \
     --set proxyAddressForwarding=true

# Install Postgres database for OpenFTTH eventstore
# Username and password should be changed in live env.
helm upgrade --install openftth-event-store bitnami/postgresql \
     --version 10.3.18 \
     --namespace openftth \
     --set global.postgresql.postgresqlDatabase=EVENT_STORE \
     --set global.postgresql.postgresqlUsername=postgres \
     --set global.postgresql.postgresqlPassword=postgres \
     --set service.type=ClusterIP

# Install OpenFTTH
helm install openftth openftth --namespace openftth

# Install go-http-file-server
helm upgrade --install file-server  dax/go-http-file-server \
  --version 2.1.0 \
  --namespace openftth \
  --set username=user1 \
  --set password=pass1

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: file-server-ingress
  namespace: openftth
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-body-size: 10m
spec:
  rules:
  - host: files.openftth.local
    http:
      paths:
      - path: /
        backend:
          serviceName: file-server-go-http-file-server
          servicePort: 80
EOF

# Install Mbtileserver route-network
helm upgrade --install openftth-routenetwork-tileserver dax/mbtileserver \
  --version 4.1.0 \
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

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: routenetwork-tileserver-ingress
  namespace: openftth
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  rules:
  - host: tiles-routenetwork.openftth.local
    http:
      paths:
      - path: /
        backend:
          serviceName: custom-tileserver-mbtileserver
          servicePort: 80
EOF

# Install Mbtileserver base-map
helm upgrade --install openftth-basemap-tileserver dax/mbtileserver \
  --version 4.1.0 \
  --namespace openftth \
  --set image.tag=danish-1621954230 \
  --set 'commandArgs={--enable-reload-signal, --disable-preview, -d, /tilesets}'

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: basemap-tileserver-ingress
  namespace: openftth
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  rules:
  - host: tiles-basemap.openftth.local
    http:
      paths:
      - path: /
        backend:
          serviceName: basemap-tileserver-mbtileserver
          servicePort: 80
EOF

# Custom tile-server
helm upgrade --install custom-tileserver dax/mbtileserver \
  --version 4.1.0 \
  --namespace openftth \
  --set watcher.enabled=true \
  --set watcher.fileServer.username=user1 \
  --set watcher.fileServer.password=pass1 \
  --set watcher.fileServer.uri=http://file-server-go-http-file-server \
  --set watcher.kafka.consumer=tile_watcher_custom \
  --set watcher.kafka.server=openftth-kafka-cluster-kafka-bootstrap:9092 \
  --set "watcher.tileProcess.processes[0].name=TILEPROCESS__PROCESS__customer_area.geojson" \
  --set "watcher.tileProcess.processes[0].value=-z17 -pS -P -o /tmp/customer_area.mbtiles /tmp/customer_area.geojson --force --quiet" \
  --set 'commandArgs={--enable-reload-signal, -d, /data}'

cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: custom-tileserver-ingress
  namespace: openftth
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  rules:
  - host: tiles-custom.openftth.local
    http:
      paths:
      - path: /
        backend:
          serviceName: custom-tileserver-mbtileserver
          servicePort: 80
EOF

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
     --version 1.1.13 \
     --namespace openftth \
     --set schedule="0 0 * * *" \
     --set connectionString="Host=openftth-postgis;Port=5432;Username=postgres;Password=postgres;Database=OPEN_FTTH" \
     --set typesense.host="openftth-search-typesense" \
     --set typesense.apiKey=changeMe!

# Install Route-network-search-indexer
helm upgrade --install route-network-search-indexer dax/route-network-search-indexer \
     --version 1.2.1 \
     --namespace openftth \
     --set kafka.positionConnectionString="Host=openftth-postgis;Port=5432;Username=postgres;Password=postgres;Database=OPEN_FTTH" \
     --set typesense.apiKey=changeMe!

# Install relational projector
helm upgrade --install relational-projector dax/relational-projector \
     --version 1.0.8 \
     --namespace openftth \
     --set eventStoreDatabase.username=postgres \
     --set eventStoreDatabase.password=postgres \
     --set geoDatabase.username=postgres \
     --set geoDatabase.username=postgres

# Route network tile data extract
helm upgrade --install route-network-tile-data-extract dax/open-ftth-tile-data-extract \
     --version 1.0.0 \
     --namespace openftth \
     --set postgisConnectionString="Host=openftth-postgis;Port=5432;Username=postgres;Password=postgres;Database=OPEN_FTTH" \
     --set fileServer.uri=http://file-server-go-http-file-server \
     --set fileServer.username=user1 \
     --set fileServer.password=pass1
