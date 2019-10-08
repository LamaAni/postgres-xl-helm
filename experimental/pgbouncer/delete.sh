#!/bin/bash

helm delete zav-db-tran
kubectl delete deployment pgbouncer-deployment
