# OPEN-FTTH Kubernetes Setup

Helm Chart for OPEN-FTTH

## Requirements

* Kubectl
* Helm 3
* Kubernetes Cluster

## Setup development

To setup the cluster run the following command. Note that the setup script is for development purposes, to run a production enviroment make an overwrite file, to overwrite secrets and use production settings. The current setup uses Danish data (maps, address information and so on). So if you want to use it with other information you will have to implement the integrations or contact us for consulting.

``` sh
./scripts/setup.sh
```

After the initial setup and Keycloak is in a healthy state, run the following script. This setups Keycloak with a default user, if you want to create a new user you will have to log into the Keycloak backend and create it there, the login information can be found querying the Kubernetes secret for Keycloak.

```sh
./scripts/keycloak/keycloak-default-setup.sh
```
