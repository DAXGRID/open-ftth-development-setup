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
USER_ROLE_CLIENT_SCOPE_FILE=$DIR_PATH"/user-role-client-scope.json"
USER_ROLE_CLIENT_SCOPE_MAPPER_FILE=$DIR_PATH"/user-role-client-scope-mapper.json"
ADD_USER_ROLE_DEFAULT_CLIENT_SCOPE=$DIR_PATH"/add-user-role-default-client-scope.json";
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

# Verify that the realm has been created
${CURL_CMD} \
  -X GET \
  -H "Accept: application/json" \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "${KEYCLOAK_URL}/auth/admin/realms/${NEW_REALM}"|jq -r .|head;

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

# Create user_role client scope
${CURL_CMD} \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @"${USER_ROLE_CLIENT_SCOPE_FILE}" \
  "${KEYCLOAK_URL}/auth/admin/realms/${NEW_REALM}/client-scopes";

# Create user_role role mappings
${CURL_CMD} \
  -X POST \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @"${USER_ROLE_CLIENT_SCOPE_MAPPER_FILE}" \
  "${KEYCLOAK_URL}/auth/admin/realms/${NEW_REALM}/client-scopes/ffa29964-3d6a-4a2d-bdbe-32917ea7d9e9/protocol-mappers/models";

# Add user to default client scope
${CURL_CMD} \
  -X PUT \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d @"${USER_ROLE_CLIENT_SCOPE_MAPPER_FILE}" \
  "${KEYCLOAK_URL}/auth/admin/realms/${NEW_REALM}/clients/c78c48cf-6d12-4946-8ecf-24da7820c5b2/default-client-scopes/ffa29964-3d6a-4a2d-bdbe-32917ea7d9e9";
