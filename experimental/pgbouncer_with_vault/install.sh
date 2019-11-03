#!/usr/bin/env bash

CHART_NAME="db-vlt-pgb"
PGXL_SERVICE_NAME="${CHART_NAME}-postgres-xl-svc"

export SECRET_NAME="pgxl-passwords-collection"
export SECRET_KEY="pgpass"
PASSWORD="your_password1"
SECRET_VALUE="$(printf "%s" "${PASSWORD}" | base64)"
export SECRET_VALUE=$SECRET_VALUE

SINGLE_NODE_CLUSTER="false"
CONSUL_NAME="consul"
export VAULT_NAME="vault"
#=================================================================================================
# REUSABLE FUNCTIONS
#-------------------------------------------------------------------------------------------------
source ./functions.sh
#=================================================================================================

#=================================================================================================
# SETUP PGXL
#-------------------------------------------------------------------------------------------------
YAML_SECRET=$(replace_with_env "$(cat ./secret.yaml)")
echo "${YAML_SECRET}" | kubectl apply -f -

mkdir tmp

YAML_HELMFILE=$(replace_with_env "$(cat ./helmfile.yaml)")
echo "${YAML_HELMFILE}" > tmp/helmfile.yaml

YAML_HELM_VALUES=$(replace_with_env "$(cat ./values.yaml)")
echo "${YAML_HELM_VALUES}" > tmp/values.yaml

cd tmp && helmfile sync || exit 1
cd ../

rm -rf tmp

kubectl wait --for=condition=ready pod -l "app=${CHART_NAME}-postgres-xl" --timeout=180s
#=================================================================================================

#=================================================================================================
# SETUP CONSUL
#-------------------------------------------------------------------------------------------------
git clone --single-branch --branch v0.12.0 https://github.com/hashicorp/consul-helm.git
# Turns off affinity if one node cluster is set to true for testing purposes
sed -i "" "s/storage: 10Gi/storage: 1Gi/g" consul-helm/values.yaml
if [ "${SINGLE_NODE_CLUSTER}" = "true" ]; then
  sed -i '/affinity: |/,+8 s/^/#/' consul-helm/values.yaml
fi
helm install "${CONSUL_NAME}" ./consul-helm
rm -rf consul-helm

kubectl wait --for=condition=ready pod -l "app=${CONSUL_NAME}" --timeout=180s
#=================================================================================================

#=================================================================================================
# SETUP VAULT
#-------------------------------------------------------------------------------------------------
git clone --single-branch --branch master https://github.com/hashicorp/vault-helm.git
# Turns off affinity if one node cluster is set to true for testing purposes
if [ "${SINGLE_NODE_CLUSTER}" = "true" ]; then
  sed -i '/affinity: |/,+8 s/^/#/' vault-helm/values.yaml
fi
sed -i "" "s/HOST_IP:8500/${CONSUL_NAME}-consul-server:8500/g" vault-helm/values.yaml
sed -i "" "s/readOnlyRootFilesystem: true/readOnlyRootFilesystem: false/g" vault-helm/values.yaml
helm install "${VAULT_NAME}" ./vault-helm --set='server.ha.enabled=true'
rm -rf vault-helm

sleep 30

INIT_OUTPUT=$(kubectl exec "${VAULT_NAME}-0" -- vault operator init -n 1 -t 1)

sleep 30

UNSEAL_KEY=$(echo "${INIT_OUTPUT}" | grep 'Unseal Key 1:' | cut -d" " -f4)
UNSEAL_KEY=$(sed "s,$(printf '\033')\\[[0-9;]*[a-zA-Z],,g" <<<"${UNSEAL_KEY}") # remove ansi colour ^[[0m^M
ROOT_TOKEN=$(echo "${INIT_OUTPUT}" | grep 'Initial Root Token:' | cut -d" " -f4)
ROOT_TOKEN=$(sed "s,$(printf '\033')\\[[0-9;]*[a-zA-Z],,g" <<<"${ROOT_TOKEN}") # remove ansi colour ^[[0m^M

kubectl exec "${VAULT_NAME}-0" -- vault operator unseal "${UNSEAL_KEY}"
kubectl exec "${VAULT_NAME}-1" -- vault operator unseal "${UNSEAL_KEY}"
kubectl exec "${VAULT_NAME}-2" -- vault operator unseal "${UNSEAL_KEY}"

kubectl wait --for=condition=ready pod -l "app.kubernetes.io/name=${VAULT_NAME}" --timeout=60s

kubectl exec "${VAULT_NAME}-0" -- vault login "${ROOT_TOKEN}"
#=================================================================================================

#=================================================================================================
# CONFIGURE VAULT PGXL ENDPOINT
#-------------------------------------------------------------------------------------------------
kubectl exec "${VAULT_NAME}-0" -- vault secrets enable database
ALLOWED_VAULT_ROLES="$(printf %s "$(ls ./vault/roles | awk -F. '{print $1}')" | tr '\n' ',')"
kubectl exec "${VAULT_NAME}-0" -- vault write database/config/postgres \
  plugin_name=postgresql-database-plugin \
  allowed_roles="${ALLOWED_VAULT_ROLES}" \
  connection_url="postgresql://{{username}}:{{password}}@${PGXL_SERVICE_NAME}:5432/postgres?sslmode=disable" \
  username="postgres" \
  password="${PASSWORD}"
#=================================================================================================

#=================================================================================================
# SETUP VAULT ROLES AND POLICIES
#-------------------------------------------------------------------------------------------------
# Run all scripts from ./vault/roles directory
ls ./vault/roles | while read -r fname
do
  bash "./vault/roles/${fname}"
done

# Apply all policies from ./vault/policies directory
ls ./vault/policies | while read -r fname
do
  kubectl exec "${VAULT_NAME}-0" -- sh -c "echo '$(cat "./vault/policies/${fname}")' > ~/${fname}; vault policy write ${fname%%.*} ~/${fname};"
done
#=================================================================================================

#=================================================================================================
# SETUP K8S AUTH FOR VAULT
#-------------------------------------------------------------------------------------------------
kubectl apply -f postgres-serviceaccount.yaml
#-------------------------------------------------------------------------------------------------
VAULT_SA_NAME=$(kubectl get sa postgres-vault -o jsonpath="{.secrets[*]['name']}")
SA_JWT_TOKEN=$(
  kubectl get secret "${VAULT_SA_NAME}" -o jsonpath="{.data.token}" | base64 --decode
  echo
)
SA_CA_CRT=$(
  kubectl get secret "${VAULT_SA_NAME}" -o jsonpath="{.data['ca\.crt']}" | base64 --decode
  echo
)
K8S_HOST=$(kubectl exec "${CONSUL_NAME}-consul-server-0" -- sh -c 'echo $KUBERNETES_SERVICE_HOST')
kubectl exec "${VAULT_NAME}-0" -- vault auth enable kubernetes
kubectl exec "${VAULT_NAME}-0" -- vault write auth/kubernetes/config \
  token_reviewer_jwt="${SA_JWT_TOKEN}" \
  kubernetes_host="https://${K8S_HOST}:443" \
  kubernetes_ca_cert="${SA_CA_CRT}"
ALLOWED_VAULT_POLICIES="$(printf %s "$(ls ./vault/policies | awk -F. '{print $1}')" | tr '\n' ',')"
kubectl exec "${VAULT_NAME}-0" -- vault write auth/kubernetes/role/postgres \
  bound_service_account_names=postgres-vault \
  bound_service_account_namespaces=default \
  policies="${ALLOWED_VAULT_POLICIES}" \
  ttl=24h
#=================================================================================================

#=================================================================================================
# SETUP PGBOUNCER
#-------------------------------------------------------------------------------------------------
YAML_PGBOUNCER_DEPLOYMENT=$(replace_with_env "$(cat ./pgbouncer/pgbouncer-deployment.yaml)")
echo "${YAML_PGBOUNCER_DEPLOYMENT}" | kubectl apply -f -
kubectl apply -f ./pgbouncer/pgbouncer-service.yaml
#=================================================================================================

#=================================================================================================
echo "Your vault details are:
Unseal Key 1: ${UNSEAL_KEY}
Initial Root Token: ${ROOT_TOKEN}
Keep them safe!"
#=================================================================================================
