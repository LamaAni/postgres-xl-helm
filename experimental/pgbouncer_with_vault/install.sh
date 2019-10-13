#!/bin/bash

SECRETS_FILE="pwd_secret.yaml"
PASSWORD="your_password1"

SINGLE_NODE_CLUSTER="true"
CONSUL_NAME="consul"
VAULT_NAME="vault"
PGXL_SERVICE_NAME="db-vlt-pgb-postgres-xl-svc"

#=================================================================================================
# SETUP PGXL
#-------------------------------------------------------------------------------------------------
BASE64_PASSWORD=$(printf "${PASSWORD}" | base64)

echo "apiVersion: v1
kind: Secret
metadata:
  name:  pgxl-passwords-collection
type: Opaque
data:
  # You must base64 encode your values. See: https://kubernetes.io/docs/concepts/configuration/secret/
  pgpass: \"${BASE64_PASSWORD}\"" > "${SECRETS_FILE}"

kubectl apply -f $SECRETS_FILE || exit 1
helmfile sync || exit 1
#=================================================================================================

#=================================================================================================
# SETUP CONSUL
#-------------------------------------------------------------------------------------------------
# Turns of affinity if one node cluster is set to true for testing purposes
git clone --single-branch --branch v0.9.0 https://github.com/hashicorp/consul-helm.git
if [ "$SINGLE_NODE_CLUSTER" = true ] ; then
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
UNSEAL_KEY=$(sed 's/\x1b\[[0-9;]*m//g' <<< $UNSEAL_KEY) # remove ansi colour ^[[0m^M
ROOT_TOKEN=$(echo "${INIT_OUTPUT}" | grep 'Initial Root Token:' | cut -d" " -f4)
ROOT_TOKEN=$(sed 's/\x1b\[[0-9;]*m//g' <<< $ROOT_TOKEN) # remove ansi colour ^[[0m^M

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
    allowed_roles="postgres-role" \
    connection_url="postgresql://{{username}}:{{password}}@${PGXL_SERVICE_NAME}:5432/postgres?sslmode=disable" \
    username="postgres" \
    password="${PASSWORD}"

CONNECTION_POOL_ROLE_CREATION="
CREATE ROLE connection_pool;
CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}' IN ROLE connection_pool;
"

CONNECTION_POOL_PGSHADOW_LOOKUP_FUNCTION="
CREATE SCHEMA connection_pool;
GRANT USAGE ON SCHEMA connection_pool TO connection_pool;
CREATE OR REPLACE FUNCTION connection_pool.lookup (
   INOUT p_user     name,
   OUT   p_password text
) RETURNS record
   LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog AS
\$FUNC\$ SELECT usename, passwd FROM pg_shadow WHERE usename = p_user \$FUNC\$;
REVOKE EXECUTE ON FUNCTION connection_pool.lookup(name) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION connection_pool.lookup(name) TO connection_pool;
"


kubectl exec -it "${VAULT_NAME}-0" -- vault write database/roles/postgres-role \
    db_name=postgres \
    creation_statements="
    ${CONNECTION_POOL_ROLE_CREATION}
    ${CONNECTION_POOL_PGSHADOW_LOOKUP_FUNCTION}
    " \
    default_ttl="1h" \
    max_ttl="24h"
#=================================================================================================

#=================================================================================================
# SETUP K8S AUTH FOR VAULT
#-------------------------------------------------------------------------------------------------
kubectl exec -it "${VAULT_NAME}-0" -- sh -c "echo 'path \"database/creds/postgres-role\" {
  capabilities = [\"read\"]
}
path \"sys/leases/renew\" {
  capabilities = [\"create\"]
}
path \"sys/leases/revoke\" {
  capabilities = [\"update\"]
}' > postgres-policy.hcl; \
vault policy write postgres-policy postgres-policy.hcl;"
#-------------------------------------------------------------------------------------------------
cat > postgres-serviceaccount.yml <<EOF
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: postgres-vault
  namespace: default
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: postgres-vault
EOF
#-------------------------------------------------------------------------------------------------
kubectl apply -f postgres-serviceaccount.yml
rm -rf postgres-serviceaccount.yml
#-------------------------------------------------------------------------------------------------
VAULT_SA_NAME=$(kubectl get sa postgres-vault -o jsonpath="{.secrets[*]['name']}"); \
SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo); \
SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo); \
K8S_HOST=$(kubectl exec consul-consul-server-0 -- sh -c 'echo $KUBERNETES_SERVICE_HOST'); \
kubectl exec -it "${VAULT_NAME}-0" -- vault auth enable kubernetes; \
kubectl exec -it "${VAULT_NAME}-0" -- vault write auth/kubernetes/config \
  token_reviewer_jwt="$SA_JWT_TOKEN" \
  kubernetes_host="https://$K8S_HOST:443" \
  kubernetes_ca_cert="$SA_CA_CRT"; \
kubectl exec -it "${VAULT_NAME}-0" -- vault write auth/kubernetes/role/postgres \
    bound_service_account_names=postgres-vault \
    bound_service_account_namespaces=default \
    policies=postgres-policy \
    ttl=24h;
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
