#!/bin/bash

# Create namespace
kubectl create namespace openftth

# Install Strimzi
helm repo add strimzi https://strimzi.io/charts/
helm repo add grafana https://grafana.github.io/loki/charts

helm repo update

# Install strimzi
helm install strimzi strimzi/strimzi-kafka-operator -n openftth --version 0.19

# Install loki
helm upgrade --install loki --namespace=openftth grafana/loki-stack  --set grafana.enabled=true,prometheus.enabled=true,prometheus.alertmanager.persistentVolume.enabled=false,prometheus.server.persistentVolume.enabled=false,loki.persistence.enabled=true,loki.persistence.storageClassName=standard,loki.persistence.size=10Gi --version jk

# This is needed to make sure that the strimzi custom types are being registered
sleep 1s

# Install OpenFTTH
helm install openftth openftth -n openftth
