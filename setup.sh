#!/bin/sh

helm repo add confluentinc https://confluentinc.github.io/cp-helm-charts/   #(1)
helm repo update    #(2)

kubectl create ns openftth

helm install openftth --set cp-schema-registry.enabled=false,cp-kafka-rest.enabled=false,cp-control-center.enabled=false confluentinc/cp-helm-charts --namespace openftth
