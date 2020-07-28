#!/bin/bash

path=c:/windows/system32/drivers/etc/hosts

minikube=$(minikube ip)
postgis=$minikube:$(kubectl describe service openftth-postgis -n openftth | grep NodePort | grep -o '[0-9]\+')

kafka=$minikube:$(kubectl describe service openftth-kafka-cluster-kafka-external-bootstrap -n openftth | grep NodePort | grep -o '[0-9]\+')

echo "Exporting $postgis with netsh"
netsh interface portproxy add v4tov4 listenport=5432 listenaddress=127.65.43.21 connectport=$postgis connectaddress=$minikube

echo "Exporting $kafka with netsh"
netsh interface portproxy add v4tov4 listenport=5432 listenaddress=127.65.43.21 connectport=$kafka connectaddress=$minikube

sed -i '/openftth/d' $path
echo 127.65.43.21 >> $path
