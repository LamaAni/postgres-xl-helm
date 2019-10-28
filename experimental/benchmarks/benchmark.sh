#!/usr/bin/env bash

CHART_NAME="transient"
SERVICE_NAME="${CHART_NAME}-postgres-xl-svc"
DEPLOYMENT_NAME="postgres-xl-pgbench-tools"

(cd "../../examples/deployments/${CHART_NAME}_db" && helmfile sync || echo "there was an error with deployment" && exit 1)
(kubectl wait --for=condition=ready pod -l "app=${CHART_NAME}-postgres-xl" --timeout=60s || echo "there was an error with deployment" && exit 1)
echo "successfully installed ${CHART_NAME}"
sleep 15

kubectl run "${DEPLOYMENT_NAME}" --image sstubbs/pgxl-pgbench-tools -- bash -c "touch temp && tail -f temp"
kubectl wait --for=condition=ready pod -l "run=${DEPLOYMENT_NAME}" --timeout=60s || echo "there was an error with deployment" && exit 1
POD_NAME=$(kubectl get pod -l run="${DEPLOYMENT_NAME}" -o jsonpath="{.items[0].metadata.name}")

kubectl exec "${POD_NAME}" -- psql -h "${SERVICE_NAME}" -c "CREATE DATABASE results;"
kubectl exec "${POD_NAME}" -- psql -h "${SERVICE_NAME}" -c "CREATE DATABASE pgbench;"

kubectl exec "${POD_NAME}" -- sed -i '0,/  );/{s/  );/  ) DISTRIBUTE BY REPLICATION;/}' init/resultdb.sql
kubectl exec "${POD_NAME}" -- psql -h "${SERVICE_NAME}" -f init/resultdb.sql -d results

kubectl exec "${POD_NAME}" -- sed -i "s/TESTHOST=localhost/TESTHOST=${SERVICE_NAME}/g" config
kubectl exec "${POD_NAME}" -- sed -i "s/RESULTHOST="\$TESTHOST"/RESULTHOST=${SERVICE_NAME}/g" config
kubectl exec "${POD_NAME}" -- ./newset 'Initial Config'

kubectl exec "${POD_NAME}" -- ./runset

mkdir results
kubectl cp "${POD_NAME}":results results/

kubectl delete deployment "${DEPLOYMENT_NAME}"

helm delete "${CHART_NAME}"
