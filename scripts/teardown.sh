#!/usr/bin/env bash
set -euo pipefail

helm uninstall openftth -n openftth
helm uninstall strimzi -n openftth
kubectl delete ns openftth
