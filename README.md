# Setting up open-ftth on kubernetes
Documentation and config files for open-ftth on Kubernetes

## Requirements

* Kubectl
* Helm
* Configured Kubernetes cluster with provisioned storage
* Git

## Setup

Following section describes the setup of the cluster

### Before starting

#### Add the following repos to helm

```sh
helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
```

### Setup with script

To setup the whole thing just run setup.sh

```sh
./setup.sh
```

### Manual setup

To setup the cluster manually calling each command.

#### Create openftth namespace

```sh
kubectl create ns openftth
```

### Kafka

```sh
helm install --generate-name --namespace openftth incubator/kafka
```

### KSQL

```sh
helm install --set cp-zookeeper.url="unhinged-robin-cp-zookeeper:2181",cp-schema-registry.url="http://lolling-chinchilla-cp-schema-registry:8081" cp-helm-charts/charts/cp-ksql-server --namespace openftth --generate-name
```
