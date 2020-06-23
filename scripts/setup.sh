#!/bin/bash

# Create namespace
kubectl create namespace openftth

# Install Strimzi
helm repo add strimzi https://strimzi.io/charts/
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add elastic https://helm.elastic.co

helm repo update

helm install strimzi strimzi/strimzi-kafka-operator -n openftth --version 0.18

# This is needed to make sure that the strimzi custom types are being registered
sleep 1s

# Build dependencies
helm dependencies build openftth

# Install OpenFTTH
helm install openftth openftth -n openftth

