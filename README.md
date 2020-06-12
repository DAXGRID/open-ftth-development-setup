# Setting up open-ftth on kubernetes

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

## Teardown

Run the following script to teardown the cluster.

``` sh
./teardown.sh
```
