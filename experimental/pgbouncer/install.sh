#!/bin/bash

SECRETS_FILE="pwd_secret.yaml"
PASSWORD="your_password1"
AUTH_METHOD="scram-sha-256"

#=================================================================================================
# SETUP PGXL
#-------------------------------------------------------------------------------------------------
git clone https://github.com/LamaAni/PGXL-HELM.git
cd PGXL-HELM/examples/deployments/with_password

echo "datanodes:
  count: 1
coordinators:
  count: 1
proxies:
  count: 1
  enabled: true

security:
  passwords_secret_name: pgxl-passwords-collection
  pg_password: pgpass
  postgres_auth_type: ${AUTH_METHOD}

config.append: |
  max_connections = 500" > values.yaml

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
PGBOUNCER_PASSWORD=""
if [ "${AUTH_METHOD}" == "md5" ]; then
    PGBOUNCER_PASSWORD="md5$(echo -n "${PASSWORD}postgres" | md5sum | awk '{print $1}')"
else
    PGBOUNCER_PASSWORD="${PASSWORD}"
fi

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
              auth_type = ${AUTH_METHOD}
              ignore_startup_parameters = extra_float_digits, intervalStyle
              auth_file = /etc/pgbouncer/userlist.txt
              auth_query = SELECT p_user, p_password FROM connection_pool.lookup(\\\$1)
              auth_user = postgres

              # Log settings
              admin_users = postgres\" > /etc/pgbouncer/pgbouncer.ini;
            echo \"\\\"postgres\\\" \\\"${PGBOUNCER_PASSWORD}\\\"\" > /etc/pgbouncer/userlist.txt;
            exec /opt/pgbouncer/pgbouncer /etc/pgbouncer/pgbouncer.ini;" > pgbouncer-deployment.yaml


kubectl apply -f pgbouncer-deployment.yaml

rm -rf pgbouncer-deployment.yaml
#=================================================================================================
