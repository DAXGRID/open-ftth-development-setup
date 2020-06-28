#!/usr/bin/env bash
set -euo pipefail

helm uninstall strimzi -n openftth
helm uninstall openftth -n openftth
