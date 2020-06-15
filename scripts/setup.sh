#!/bin/sh

# Create namespace
kubectl create namespace openftth

# Install Strimzi
helm repo add strimzi https://strimzi.io/charts/
helm repo update
helm install strimzi strimzi/strimzi-kafka-operator \
   --namespace openftth \
   --version 0.18

# Install OpenFTTH

# This is needed to make sure that the strimzi custom types are being registered
sleep 1s

helm install openftth openftth/ \
  --namespace openftth

