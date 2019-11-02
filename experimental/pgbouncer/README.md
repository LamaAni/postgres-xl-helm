# THIS SCRIPT IS HIGHLY EXPERIMENTAL!

Please note this is only here temporarily as it will eventually be moved out into another chart.

- This example creates a transient deployment which will not persist between restarts using a kubernetes secret.
- It uses an init script to create a pg_shadow lookup function which is required by pgbouncer auth_query.
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
