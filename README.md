# OPEN-FTTH Kubernetes Setup

Documentation and config files for open-ftth on Kubernetes

## Requirements

* Kubectl
* Helm 3
* Configured Kubernetes cluster with provisioned storage

## Setup

To setup the cluster run the following command.

``` sh
./scripts/setup.sh
```

## Setup Development environment / Local testing

To setup the development/test cluster run the following command.

``` sh
./scripts/setup-dev.sh
```

## Teardown

Run the following script to teardown the cluster.

``` sh
./teardown.sh
```
