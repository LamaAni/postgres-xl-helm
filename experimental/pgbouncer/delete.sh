#!/bin/bash

helm delete db-pgb
kubectl delete deployment pgbouncer
kubectl delete service pgbouncer-svc
