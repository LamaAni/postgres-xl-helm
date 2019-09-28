#!/bin/bash
PGXL_NAME="pgxl"
CONSUL_NAME="consul"
VAULT_NAME="vault"

helm delete "${PGXL_NAME}"
helm delete "${CONSUL_NAME}"
helm delete "${VAULT_NAME}"

rm -rf PGXL-HELM
rm -rf consul-helm
rm -rf vault-helm
