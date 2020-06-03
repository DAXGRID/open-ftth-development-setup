#!/bin/sh

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Create project namespace
kubectl create ns openftth

# Setup cassandra
helm install openftth-cassandra bitnami/cassandra -n openftth

# Setup Postgis
kubectl apply -f ./postgis/postgis.yaml -n openftth

# Create Strimzi Kafka   
kubectl apply -f 'https://strimzi.io/install/latest?namespace=openftth' -n openftth
kubectl apply -f 'https://strimzi.io/examples/latest/kafka/kafka-persistent-single.yaml' -n openftth

# Create secret for postgres connector
kubectl -n openftth create secret generic postgres-credentials \
  --from-file=./secrets/debezium-postgres-credentials.properties

# Create postgres connector for postgis
kubectl create -f ./connectors/postgres-connect-cluster.yaml -n openftth
kubectl create -f ./connectors/postgis-connector.yaml -n openftth
