#!/usr/bin/env bash

helm delete db-vlt-pgb
helm delete consul
helm delete vault
kubectl delete deployment pgbouncer
kubectl delete service pgbouncer-svc
kubectl delete pvc data-default-consul-consul-server-0 data-default-consul-consul-server-1 data-default-consul-consul-server-2
kubectl delete secret pgxl-passwords-collection