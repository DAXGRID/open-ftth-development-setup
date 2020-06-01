#!/bin/sh

helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator

kubectl create ns openftth

helm install openftth-kafka --namespace openftth incubator/kafka

git clone https://github.com/confluentinc/cp-helm-charts.git

helm install openftth-ksql --set cp-zookeeper.url="openffth-zookeeper:2181",cp-schema-registry.url="http://lolling-chinchilla-cp-schema-registry:8081" cp-helm-charts/charts/cp-ksql-server --namespace openftth

rm -rf cp-helm-charts
