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
helm install strimzi strimzi/strimzi-kafka-operator -n openftth --version 0.19

# Install loki
helm upgrade --install loki --namespace=openftth grafana/loki-stack --set grafana.enabled=true,prometheus.enabled=true,prometheus.alertmanager.persistentVolume.enabled=false,prometheus.server.persistentVolume.enabled=false,loki.persistence.enabled=true,loki.persistence.storageClassName=standard,loki.persistence.size=10Gi --version 2.3.0

# Install Keycloak
helm upgrade --install keycloak bitnami/keycloak -n openftth --version 1.2.0 --set service.type=ClusterIP

# Install OpenFTTH
helm install openftth openftth -n openftth

# Install Nginx-Ingress
helm install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace openftth \
    --set controller.replicaCount=1

# Install the cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace openftth \
  --version v1.1.0 \
  --set installCRDs=true
