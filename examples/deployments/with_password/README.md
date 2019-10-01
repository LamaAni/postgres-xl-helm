# Using secrets for password in pgxl

The pgxl chart dose not apply the kubernetes secret, therefore we must first apply that. To apply the secret run:
```shell
kubectl apply -f ./pwd_secret.yaml
```

Then you sync with helmfile,
```shell
helmfile sync
```

Example secrets config,
```yaml
apiVersion: v1
kind: Secret
metadata:
  name:  pgxl-passwords-collection
type: Opaque
data:
  # You must base64 encode your values. See: https://kubernetes.io/docs/concepts/configuration/secret/
  pgpass: "bGFtYQ=="
```

For encoding to base64, 
```shell
printf "mypass" | base64
```
Note, do not use echo, it will add a newline.