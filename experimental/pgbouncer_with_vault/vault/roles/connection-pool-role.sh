#!/usr/bin/env bash

#=================================================================================================
# REUSABLE FUNCTIONS
#-------------------------------------------------------------------------------------------------
source functions.sh
#=================================================================================================

#=================================================================================================
# CREATE THE ROLE
#-------------------------------------------------------------------------------------------------
CONNECTION_POOL_ROLE_CREATION=(
  "$(cat ./vault/sql/connection-pool-create-inherited-user.sql)"
)

CONNECTION_POOL_ROLE_CREATION_JSON=$(json_array "${CONNECTION_POOL_ROLE_CREATION[@]}")

kubectl exec -it "${VAULT_NAME}-0" -- vault write database/roles/connection-pool-role \
  db_name=postgres \
  creation_statements="${CONNECTION_POOL_ROLE_CREATION_JSON}" \
  default_ttl="1h" \
  max_ttl="24h"
#=================================================================================================