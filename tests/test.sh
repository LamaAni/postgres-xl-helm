#!/usr/bin/env bash

CHART_NAME="transient"
export DATABASE_NAME="test_db"
export SCHEMA_NAME="test_schema"
export TABLE_NAME="test_table"

#=================================================================================================
# REUSABLE FUNCTIONS
#-------------------------------------------------------------------------------------------------
source './functions.sh'
source './assert.sh'
#=================================================================================================

#=================================================================================================
# INSTALL CHART
#-------------------------------------------------------------------------------------------------
log_header "Start tests postgres-xl-docker : ${CHART_NAME}"
#-------------------------------------------------------------------------------------------------
# Install the chart
install_chart() {
  log_header "Test :: deploy"
  (cd "../examples/deployments/${CHART_NAME}_db" && helmfile sync || log_failure "there was an error with deployment" && exit 1)
  (kubectl wait --for=condition=ready pod -l "app=${CHART_NAME}-postgres-xl" --timeout=60s || log_failure "there was an error with deployment" && exit 1)
  log_success "successfully installed ${CHART_NAME}"
  sleep 5
}
#=================================================================================================

#=================================================================================================
# TESTS
#-------------------------------------------------------------------------------------------------
# Create a test database
test_create_database() {
  log_header "Test :: create database"

  SQL_CREATE_DATABASE=$(replace_with_env "$(cat ./sql/create_database.sql)")

  RESULT=$(kubectl exec -it "${CHART_NAME}-postgres-xl-crd-0" -- psql -c "${SQL_CREATE_DATABASE}" | tr -d '\r')

  assert_eq "${RESULT}" "CREATE DATABASE"
  if [ "$?" == 0 ]; then
    log_success "successfully created database"
  else
    log_failure "there was an error creating the database"
  fi
}
#-------------------------------------------------------------------------------------------------
# Create a test schema
test_create_schema() {
  log_header "Test :: create schema"

  SQL_CREATE_SCHEMA=$(replace_with_env "$(cat ./sql/create_schema.sql)")

  RESULT=$(kubectl exec -it "${CHART_NAME}-postgres-xl-crd-0" -- psql -d "${DATABASE_NAME}" -c "${SQL_CREATE_SCHEMA}" | tr -d '\r')

  assert_eq "${RESULT}" "CREATE SCHEMA"
  if [ "$?" == 0 ]; then
    log_success "successfully created schema"
  else
    log_failure "there was an error creating the schema"
  fi
}
#-------------------------------------------------------------------------------------------------
# Create a test table
test_create_table() {
  log_header "Test :: create table"

  SQL_CREATE_TABLE=$(replace_with_env "$(cat ./sql/create_table.sql)")

  RESULT=$(kubectl exec -it "${CHART_NAME}-postgres-xl-crd-0" -- psql -d "${DATABASE_NAME}" -c "${SQL_CREATE_TABLE}" | tr -d '\r')

  assert_eq "${RESULT}" "INSERT 0 1"
  if [ "$?" == 0 ]; then
    log_success "successfully created table"
  else
    log_failure "there was an error creating the table"
  fi
}
#-------------------------------------------------------------------------------------------------
# Query data
test_query_data() {
  log_header "Test :: query data"

  SQL_QUERY_DATA=$(replace_with_env "$(cat ./sql/query_data.sql)")

  RESULT=$(kubectl exec -it "${CHART_NAME}-postgres-xl-crd-0" -- psql -t -d "${DATABASE_NAME}" -c "${SQL_QUERY_DATA}" | tr '\n' ' ' | tr -d '\r' | xargs)

  assert_eq "${RESULT}" "the brown rabbit"
  if [ "$?" == 0 ]; then
    log_success "successfully queried data"
  else
    log_failure "there was an error querying data"
  fi
}
#=================================================================================================

#=================================================================================================
# DELETE CHART
#-------------------------------------------------------------------------------------------------
# Install the chart
delete_chart() {
  helm delete "${CHART_NAME}"
  log_success "successfully deleted ${CHART_NAME}"
}
#=================================================================================================

#=================================================================================================
# RUN TESTS
#-------------------------------------------------------------------------------------------------
# Run tests
install_chart
test_create_database
test_create_schema
test_create_table
test_query_data
delete_chart

log_header "End tests postgres-xl-docker : ${CHART_NAME}"
#=================================================================================================
