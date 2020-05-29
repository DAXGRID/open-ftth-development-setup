# Setting up open-ftth on kubernetes
Documentation and config files for open-ftth on Kubernetes

## Requirements

* Kubectl
* Helm
* Configured Kubernetes cluster with provisioned storage

## Setup

Following section describes the setup of the cluster

### Before starting

Add the following repos to helm

```sh
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
```

### Kafka

```sh
kubectl create ns openffth
helm install --generate-name --namespace kafka incubator/kafka
```

### KSQL

```sh
helm install --set cp-zookeeper.url="unhinged-robin-cp-zookeeper:2181",cp-schema-registry.url="http://lolling-chinchilla-cp-schema-registry:8081" cp-helm-charts/charts/cp-ksql-server --namespace openftth --generate-name
```
