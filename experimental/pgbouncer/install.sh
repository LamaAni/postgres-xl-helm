#!/bin/bash

SECRETS_FILE="pwd_secret.yaml"
PASSWORD="your_password"

#=================================================================================================
# SETUP PGXL
#-------------------------------------------------------------------------------------------------
git clone https://github.com/LamaAni/PGXL-HELM.git
cd PGXL-HELM/examples/deployments/with_password

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

cd ../../../../
rm -rf PGXL-HELM

#=================================================================================================

#=================================================================================================
# SETUP PGBOUNCER
#-------------------------------------------------------------------------------------------------

#=================================================================================================
