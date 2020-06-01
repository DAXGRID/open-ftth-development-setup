#!/bin/sh

helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add confluentinc https://confluentinc.github.io/cp-helm-charts/
helm repo update

kubectl create ns openftth

helm install openftth-kafka --set cp-schema-registry.enabled=false,cp-kafka-rest.enabled=false,cp-control-center.enabled=false confluentinc/cp-helm-charts --namespace openftth

helm install openftth-cassandra bitnami/cassandra --namespace openftth
