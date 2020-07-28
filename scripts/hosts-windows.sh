#!/bin/bash

path=c:/windows/system32/drivers/etc/hosts

minikube=$(minikube ip)
postgis=$(kubectl describe service openftth-postgis -n openftth | grep NodePort | grep -o '[0-9]\+')

kafka=$(kubectl describe service openftth-kafka-cluster-kafka-external-bootstrap -n openftth | grep NodePort | grep -o '[0-9]\+')

echo "Exporting postgis port $postgis with netsh"
netsh interface portproxy add v4tov4 listenport=5000 listenaddress=127.65.43.25 connectport=$postgis connectaddress=$minikube

echo "Exporting kafka port $kafka with netsh"
netsh interface portproxy add v4tov4 listenport=9000 listenaddress=127.65.43.25 connectport=$kafka connectaddress=$minikube


sed -i '/openftth/d' $path
echo "127.65.43.25 openftth" >> $path
