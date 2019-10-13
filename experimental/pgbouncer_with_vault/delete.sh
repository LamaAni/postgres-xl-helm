#!/bin/bash

helm delete zav-db-tran
helm delete consul
helm delete vault
kubectl delete deployment pgbouncer
kubectl delete service pgbouncer-svc
kubectl delete pvc data-default-consul-consul-server-0 data-default-consul-consul-server-1 data-default-consul-consul-server-2
