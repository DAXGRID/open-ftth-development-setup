#!/bin/bash

# Create namespace
kubectl create namespace openftth

# Install Strimzi
helm repo add strimzi https://strimzi.io/charts/ # Used for Strimzi
helm repo add bitnami https://charts.bitnami.com/bitnami # Used for Cassandra

helm repo update

helm install strimzi strimzi/strimzi-kafka-operator -n openftth --version 0.19

# This is needed to make sure that the strimzi custom types are being registered
sleep 1s

# Update dependency
helm dependency update openftth

# Build dependencies
helm dependencies build openftth

# Install OpenFTTH
helm install openftth openftth -n openftth
