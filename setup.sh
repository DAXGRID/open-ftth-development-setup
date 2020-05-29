#!/bin/bash

helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator

kubectl create ns openftth

helm install --generate-name --namespace openftth incubator/kafka

git clone https://github.com/confluentinc/cp-helm-charts.git

helm install --set cp-zookeeper.url="unhinged-robin-cp-zookeeper:2181",cp-schema-registry.url="http://lolling-chinchilla-cp-schema-registry:8081" cp-helm-charts/charts/cp-ksql-server --namespace openftth --generate-name

cd ..
rm -rf cp-helm-charts
