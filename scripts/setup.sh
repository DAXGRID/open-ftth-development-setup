#!/bin/sh

# Create namespace
kubectl create namespace openftth

# Install Strimzi
helm repo add strimzi https://strimzi.io/charts/
helm repo add stable https://kubernetes-charts.storage.googleapis.com
helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com

helm repo update

helm install strimzi strimzi/strimzi-kafka-operator \
   --namespace openftth \
   --version 0.18

# This is needed to make sure that the strimzi custom types are being registered
sleep 1s

# Build dependencies
helm dependencies build openftth

# Install OpenFTTH
helm install openftth openftth/ \
  --namespace openftth

