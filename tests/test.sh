#!/usr/bin/env bash

CHART_NAME="transient"
export DATABASE_NAME="test_db"
export SCHEMA_NAME="test_schema"
export TABLE_NAME="test_table"

#=================================================================================================
# REUSABLE FUNCTIONS
#-------------------------------------------------------------------------------------------------
source './functions.sh'
#=================================================================================================

#=================================================================================================
# INSTALL CHART
#-------------------------------------------------------------------------------------------------
# Install the chart
testInstallChart() {
  (cd "../examples/deployments/${CHART_NAME}_db" && helmfile sync || echo "there was an error with deployment" && exit 1)
  (kubectl wait --for=condition=ready pod -l "app=${CHART_NAME}-postgres-xl" --timeout=60s || echo "there was an error with deployment" && exit 1)
  echo "successfully installed ${CHART_NAME}"
  sleep 15
  assertEquals 1 1
}
#=================================================================================================

#=================================================================================================
# TESTS
#-------------------------------------------------------------------------------------------------
# Create a test database
testCreateDatabase() {
  SQL_CREATE_DATABASE=$(replace_with_env "$(cat ./sql/create_database.sql)")

  RESULT=$(kubectl exec -it "${CHART_NAME}-postgres-xl-crd-0" -- psql -c "${SQL_CREATE_DATABASE}" | tr -d '\r')

  assertEquals "${RESULT}" "CREATE DATABASE"
}
#-------------------------------------------------------------------------------------------------
# Create a test schema
testCreateSchema() {
  SQL_CREATE_SCHEMA=$(replace_with_env "$(cat ./sql/create_schema.sql)")

  RESULT=$(kubectl exec -it "${CHART_NAME}-postgres-xl-crd-0" -- psql -d "${DATABASE_NAME}" -c "${SQL_CREATE_SCHEMA}" | tr -d '\r')

  assertEquals "${RESULT}" "CREATE SCHEMA"
}
#-------------------------------------------------------------------------------------------------
# Create a test table
testCreateTable() {
  SQL_CREATE_TABLE=$(replace_with_env "$(cat ./sql/create_table.sql)")

  RESULT=$(kubectl exec -it "${CHART_NAME}-postgres-xl-crd-0" -- psql -d "${DATABASE_NAME}" -c "${SQL_CREATE_TABLE}" | tr -d '\r')

  assertEquals "${RESULT}" "INSERT 0 1"
}
#-------------------------------------------------------------------------------------------------
# Query data
testQueryData() {
  SQL_QUERY_DATA=$(replace_with_env "$(cat ./sql/query_data.sql)")

  RESULT=$(kubectl exec -it "${CHART_NAME}-postgres-xl-crd-0" -- psql -t -d "${DATABASE_NAME}" -c "${SQL_QUERY_DATA}" | tr '\n' ' ' | tr -d '\r' | xargs)

  assertEquals "${RESULT}" "the brown rabbit"
}
#=================================================================================================

#=================================================================================================
# DELETE CHART
#-------------------------------------------------------------------------------------------------
# Install the chart
testDeleteChart() {
  helm delete "${CHART_NAME}"
  assertEquals 1 1
}
#=================================================================================================

#=================================================================================================
# RUN TESTS
#-------------------------------------------------------------------------------------------------
# Load shUnit2.
. ./shunit2.sh
#=================================================================================================
