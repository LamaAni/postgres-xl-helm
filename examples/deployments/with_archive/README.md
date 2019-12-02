# Transient example deployment with WAL archive.

This example creates a transient deployment which will not persist between restarts with additional configuration appended.
The wal archive will be saved to an empty mount folder, which can be replaced with a pvc.

Alter values as required then sync with helmfile,
```shell
helmfile sync
```