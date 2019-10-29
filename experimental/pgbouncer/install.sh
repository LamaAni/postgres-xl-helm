#!/bin/bash

export CHART_NAME="db-pgb"
export PGXL_SERVICE_NAME="${CHART_NAME}-postgres-xl-svc"

export SECRET_NAME="pgxl-passwords-collection"
export SECRET_KEY="pgpass"
PASSWORD="your_password1"
SECRET_VALUE="$(printf "%s" "${PASSWORD}" | base64)"
export SECRET_VALUE=$SECRET_VALUE

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
#=================================================================================================

#=================================================================================================
# SETUP PGBOUNCER
#-------------------------------------------------------------------------------------------------
YAML_PGBOUNCER_DEPLOYMENT=$(replace_with_env "$(cat ./pgbouncer/pgbouncer-deployment.yaml)")
echo "${YAML_PGBOUNCER_DEPLOYMENT}" | kubectl apply -f -
kubectl apply -f ./pgbouncer/pgbouncer-service.yaml
#=================================================================================================
