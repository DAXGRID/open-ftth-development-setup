#!/usr/bin/env bash

NEW_REALM="openftth"
KEYCLOAK_URL=http://$(kubectl describe service keycloak -n openftth | \
                          grep LoadBalancer | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+')
KEYCLOAK_REALM="master"
KEYCLOAK_USER="user"
KEYCLOAK_SECRET=$(kubectl get secret --namespace openftth keycloak-env-vars \
                          -o jsonpath="{.data.KEYCLOAK_ADMIN_PASSWORD}" | base64 --decode)
REALM_FILE="realm.json";
CLIENT_FILE="client.json";
CURL_CMD="curl --silent --show-error"

# Receive token
ACCESS_TOKEN=$(${CURL_CMD} \
  -X POST \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "username=${KEYCLOAK_USER}" \
  -d "password=${KEYCLOAK_SECRET}" \
  -d "grant_type=password" \
  -d 'client_id=admin-cli' \
  "${KEYCLOAK_URL}/auth/realms/${KEYCLOAK_REALM}/protocol/openid-connect/token" | jq -r '.access_token')

# Create realm
${CURL_CMD} \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @"${REALM_FILE}" \
  "${KEYCLOAK_URL}/auth/admin/realms";

# Verify that the realm was created
${CURL_CMD} \
  -X GET \
  -H "Accept: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "${KEYCLOAK_URL}/auth/admin/realms/${NEW_REALM}" | jq -r . | head;

# Create client
${CURL_CMD} \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @"${CLIENT_FILE}" \
  "${KEYCLOAK_URL}/auth/admin/realms/${NEW_REALM}/clients";
