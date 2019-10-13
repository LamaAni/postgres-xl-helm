#!/bin/bash

helm delete zav-db-tran
kubectl delete deployment pgbouncer
kubectl delete service pgbouncer-svc
