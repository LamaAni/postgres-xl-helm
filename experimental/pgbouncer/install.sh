#!/bin/bash

SECRETS_FILE="pwd_secret.yaml"
PASSWORD="your_password"

#=================================================================================================
# SETUP PGXL
#-------------------------------------------------------------------------------------------------
git clone https://github.com/LamaAni/PGXL-HELM.git
cd PGXL-HELM/examples/deployments/with_password

BASE64_PASSWORD=$(printf "${PASSWORD}" | base64)

echo "apiVersion: v1
kind: Secret
metadata:
  name:  pgxl-passwords-collection
type: Opaque
data:
  # You must base64 encode your values. See: https://kubernetes.io/docs/concepts/configuration/secret/
  pgpass: \"${BASE64_PASSWORD}\"" > "${SECRETS_FILE}"

kubectl apply -f $SECRETS_FILE || exit 1
helmfile sync || exit 1

cd ../../../../
rm -rf PGXL-HELM

#=================================================================================================

#=================================================================================================
# SETUP PGBOUNCER
#-------------------------------------------------------------------------------------------------
echo "apiVersion: apps/v1
kind: Deployment
metadata:
  name: pgbouncer-deployment
  labels:
    app: pgbouncer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pgbouncer
  template:
    metadata:
      labels:
        app: pgbouncer
    spec:
      containers:
      - name: pgbouncer
        image: pgbouncer/pgbouncer:1.11.0
        ports:
        - containerPort: 5432
        command:
          - "sh"
          - "-c"
          - >
            echo \"
              [databases]
              * = host = zav-db-tran-postgres-xl-svc port=5432

              [pgbouncer]
              max_client_conn = 1000
              default_pool_size = 5
              max_db_connections = 100
              listen_addr = *
              listen_port = 5432
              auth_type = md5
              ignore_startup_parameters = extra_float_digits, intervalStyle
              auth_file = /etc/pgbouncer/userlist.txt
              auth_query = SELECT p_user, p_password FROM connection_pool.lookup(\\\$1)
              auth_user = postgres

              # Log settings
              admin_users = postgres\" > /etc/pgbouncer/pgbouncer.ini;
            MD5_CREDENTIALS="md5$(echo -n "${PASSWORD}postgres" | md5sum | awk '{print $1}')"; echo \"\\\"postgres\\\" \\\"\${MD5_CREDENTIALS}\\\"\" > /etc/pgbouncer/userlist.txt;
            exec /opt/pgbouncer/pgbouncer /etc/pgbouncer/pgbouncer.ini;" > pgbouncer-deployment.yaml


kubectl apply -f pgbouncer-deployment.yaml

rm -rf pgbouncer-deployment.yaml
#=================================================================================================
