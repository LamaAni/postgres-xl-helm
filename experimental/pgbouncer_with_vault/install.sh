#!/bin/bash

SECRETS_FILE="pwd_secret.yaml"
PASSWORD="your_password1"

SINGLE_NODE_CLUSTER="true"
CONSUL_NAME="consul"
VAULT_NAME="vault"
PGXL_SERVICE_NAME="db-vlt-pgb-postgres-xl-svc"

#=================================================================================================
# REUSABLE FUNCTIONS
#-------------------------------------------------------------------------------------------------
source ./functions.sh
#=================================================================================================

#=================================================================================================
# SETUP PGXL
#-------------------------------------------------------------------------------------------------
BASE64_PASSWORD=$(printf "%s" "${PASSWORD}" | base64)

SECRET_TEMPLATE=$'apiVersion: v1
kind: Secret
metadata:
  name:  pgxl-passwords-collection
type: Opaque
data:
  # You must base64 encode your values. See: https://kubernetes.io/docs/concepts/configuration/secret/
  pgpass: "{{BASE64_PASSWORD}}"'

SECRET=$(replace_with_env "${SECRET_TEMPLATE}")
echo "${SECRET}" | kubectl apply -f -

helmfile sync || exit 1
#=================================================================================================

#=================================================================================================
# SETUP CONSUL
#-------------------------------------------------------------------------------------------------
# Turns of affinity if one node cluster is set to true for testing purposes
git clone --single-branch --branch v0.9.0 https://github.com/hashicorp/consul-helm.git
if [ "$SINGLE_NODE_CLUSTER" = true ]; then
  sed -i '/affinity: |/,+8 s/^/#/' consul-helm/values.yaml
fi
helm install "${CONSUL_NAME}" ./consul-helm
rm -rf consul-helm

sleep 60
#=================================================================================================

#=================================================================================================
# SETUP VAULT
#-------------------------------------------------------------------------------------------------
git clone --single-branch --branch v0.1.2 https://github.com/hashicorp/vault-helm.git
sed -i "s/HOST_IP:8500/${CONSUL_NAME}-consul-server:8500/g" vault-helm/values.yaml
helm install "${VAULT_NAME}" ./vault-helm --set='server.ha.enabled=true'
rm -rf vault-helm

sleep 15

INIT_OUTPUT=$(kubectl exec -it "${VAULT_NAME}-0" -- vault operator init -n 1 -t 1)

sleep 15

UNSEAL_KEY=$(echo "${INIT_OUTPUT}" | grep 'Unseal Key 1:' | cut -d" " -f4)
UNSEAL_KEY=$(sed 's/\x1b\[[0-9;]*m//g' <<<$UNSEAL_KEY) # remove ansi colour ^[[0m^M
ROOT_TOKEN=$(echo "${INIT_OUTPUT}" | grep 'Initial Root Token:' | cut -d" " -f4)
ROOT_TOKEN=$(sed 's/\x1b\[[0-9;]*m//g' <<<$ROOT_TOKEN) # remove ansi colour ^[[0m^M

kubectl exec -it "${VAULT_NAME}-0" -- vault operator unseal "${UNSEAL_KEY}"
kubectl exec -it "${VAULT_NAME}-1" -- vault operator unseal "${UNSEAL_KEY}"
kubectl exec -it "${VAULT_NAME}-2" -- vault operator unseal "${UNSEAL_KEY}"

sleep 15

kubectl exec -it "${VAULT_NAME}-0" -- vault login "${ROOT_TOKEN}"
#=================================================================================================

#=================================================================================================
# SETUP VAULT PGXL ROLES
#-------------------------------------------------------------------------------------------------
kubectl exec -it "${VAULT_NAME}-0" -- vault secrets enable database
kubectl exec -it "${VAULT_NAME}-0" -- vault write database/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="connection-pool-role" \
  connection_url="postgresql://{{username}}:{{password}}@${PGXL_SERVICE_NAME}:5432/postgres?sslmode=disable" \
  username="postgres" \
  password="${PASSWORD}"

CONNECTION_POOL_ROLE_CREATION=(
  "DO \$FUNC\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'connection_pool') THEN
        CREATE ROLE connection_pool;
    END IF;
END
\$FUNC\$;"
  "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' IN ROLE connection_pool;"
)

CONNECTION_POOL_PGSHADOW_LOOKUP_FUNCTION=(
  "DO \$FUNC1\$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name = 'connection_pool') THEN
        CREATE SCHEMA connection_pool;
        GRANT USAGE ON SCHEMA connection_pool TO connection_pool;
        CREATE OR REPLACE FUNCTION connection_pool.lookup (
           INOUT p_user     name,
           OUT   p_password text
        ) RETURNS record
           LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog AS
        \$FUNC2\$ SELECT usename, passwd FROM pg_shadow WHERE usename = p_user \$FUNC2\$;
        REVOKE EXECUTE ON FUNCTION connection_pool.lookup(name) FROM PUBLIC;
        GRANT EXECUTE ON FUNCTION connection_pool.lookup(name) TO connection_pool;
    END IF;
END
\$FUNC1\$;"
)

ROLE_AND_PG_SHADOW_LOOKUP=("${CONNECTION_POOL_ROLE_CREATION[@]}" "${CONNECTION_POOL_PGSHADOW_LOOKUP_FUNCTION[@]}")

ROLE_AND_PG_SHADOW_LOOKUP_JSON=$(json_array "${ROLE_AND_PG_SHADOW_LOOKUP[@]}")

kubectl exec -it "${VAULT_NAME}-0" -- vault write database/roles/connection-pool-role \
  db_name=postgres \
  creation_statements="${ROLE_AND_PG_SHADOW_LOOKUP_JSON}" \
  default_ttl="1h" \
  max_ttl="24h"
#=================================================================================================

#=================================================================================================
# SETUP K8S AUTH FOR VAULT
#-------------------------------------------------------------------------------------------------
kubectl exec -it "${VAULT_NAME}-0" -- sh -c "echo 'path \"database/creds/connection-pool-role\" {
  capabilities = [\"read\"]
}
path \"sys/leases/renew\" {
  capabilities = [\"create\"]
}
path \"sys/leases/revoke\" {
  capabilities = [\"update\"]
}' > connection-pool-role-policy.hcl; \
vault policy write connection-pool-role-policy connection-pool-role-policy.hcl;"
#-------------------------------------------------------------------------------------------------
kubectl apply -f postgres-serviceaccount.yaml
#-------------------------------------------------------------------------------------------------
VAULT_SA_NAME=$(kubectl get sa postgres-vault -o jsonpath="{.secrets[*]['name']}")
SA_JWT_TOKEN=$(
  kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode
  echo
)
SA_CA_CRT=$(
  kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode
  echo
)
K8S_HOST=$(kubectl exec consul-consul-server-0 -- sh -c 'echo $KUBERNETES_SERVICE_HOST')
kubectl exec -it "${VAULT_NAME}-0" -- vault auth enable kubernetes
kubectl exec -it "${VAULT_NAME}-0" -- vault write auth/kubernetes/config \
  token_reviewer_jwt="$SA_JWT_TOKEN" \
  kubernetes_host="https://$K8S_HOST:443" \
  kubernetes_ca_cert="$SA_CA_CRT"
kubectl exec -it "${VAULT_NAME}-0" -- vault write auth/kubernetes/role/postgres \
  bound_service_account_names=postgres-vault \
  bound_service_account_namespaces=default \
  policies=connection-pool-role-policy \
  ttl=24h
#=================================================================================================

#=================================================================================================
# SETUP PGBOUNCER
#-------------------------------------------------------------------------------------------------
kubectl apply -f pgbouncer-deployment.yaml
kubectl apply -f pgbouncer-service.yaml
#=================================================================================================

#=================================================================================================
echo "Your vault details are:
Unseal Key 1: ${UNSEAL_KEY}
Initial Root Token: ${ROOT_TOKEN}
Keep them safe!"
#=================================================================================================
