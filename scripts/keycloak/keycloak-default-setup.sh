#!/usr/bin/env bash

NEW_REALM="openftth"
KEYCLOAK_URL=http://auth.openftth.local
KEYCLOAK_REALM="master"
KEYCLOAK_USER="user"
KEYCLOAK_SECRET=$(kubectl get secret --namespace openftth keycloak -o jsonpath="{.data.admin-password}" | base64 --decode)
DIR_PATH=$(dirname $(realpath $0))
REALM_FILE=$DIR_PATH"/realm.json"
CLIENT_FILE=$DIR_PATH"/client.json"
USER_FILE=$DIR_PATH"/user.json"
CURL_CMD="curl --silent --show-error"

#Receive token
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

# Create client
${CURL_CMD} \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @"${CLIENT_FILE}" \
  "${KEYCLOAK_URL}/auth/admin/realms/${NEW_REALM}/clients";

# Create user
${CURL_CMD} \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @"${USER_FILE}" \
  "${KEYCLOAK_URL}/auth/admin/realms/${NEW_REALM}/users";
