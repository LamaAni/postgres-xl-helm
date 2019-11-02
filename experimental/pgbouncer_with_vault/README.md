# THIS SCRIPT IS HIGHLY EXPERIMENTAL!

Please note this is only here temporarily as it will eventually be moved out into another chart.

- This example creates a transient deployment which will not persist between restarts.
- Then it deploys the consul chart which is required for vault https://github.com/hashicorp/consul-helm.
- Then it deploys the vault chart https://github.com/hashicorp/vault-helm and sets up roles and policies depending on what is inside the vault/policies and vault/roles folders.
- It uses an init script to create a pg_shadow lookup function and connection_pool user. Vault inherits permissions from this user when creating temporary users for pgbouncer pods which are required by pgbouncer auth_query.
- Then it creates a pgbouncer deployment and service using the yaml files in the pgbouncer folder.

# INSTALL

To test install use the below.

```shell
./install.sh
```
# DELETE

```
./delete.sh
```

# DELETE CONSUL PVC

```
./delete_consul_pvc.sh
```
