# THIS SCRIPT IS HIGHLY EXPERIMENTAL!

Please note this is only here temporarily. It is used as a basis for the pgbouncer_with_vault example and will eventually be removed.

- This example creates a transient deployment which will not persist between restarts.
- Then it deploys the consul chart which is required for vault https://github.com/hashicorp/consul-helm.
- Then it deploys the vault chart https://github.com/hashicorp/vault-helm and sets up a policy for use.

# INSTALL

To test install use the below.

```shell
./install.sh
```

# TEST K8S AUTH FOR VAULT AFTER INSTALL

```shell
kubectl run tmp --rm -i --tty --serviceaccount=postgres-vault --image alpine
```

Inside the pod execute the script,
```shell
apk update && \
    apk add curl postgresql-client jq && \
    KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token) && \
    VAULT_K8S_LOGIN=$(curl --request POST --data '{"jwt": "'"$KUBE_TOKEN"'", "role": "postgres"}' http://vault:8200/v1/auth/kubernetes/login) && \
    X_VAULT_TOKEN=$(echo $VAULT_K8S_LOGIN | jq -r '.auth.client_token') && \
    POSTGRES_CREDS=$(curl --header "X-Vault-Token: $X_VAULT_TOKEN" http://vault:8200/v1/database/creds/postgres-role) && \
    PGUSER=$(echo $POSTGRES_CREDS | jq -r '.data.username') && \
    PGPASSWORD=$(echo $POSTGRES_CREDS | jq -r '.data.password') && \
    psql -h pgxl-postgres-xl-svc -U $PGUSER postgres -c 'SELECT * FROM pg_catalog.pg_tables;'
```

# DELETE

```
./delete.sh
```

# DELETE CONSUL PVC

```
./delete_consul_pvc.sh
```
