# Example deployments

The examples in this directory are of simple, value change, deployments 
of the database. 

The examples use the tool [helmfile]() to deploy the chart onto a cluster.

# Helmfile, in (very) short

Allows for deploying helm releases, given either a directory or a repo url.
See examples above for postgres-xl, or [here](https://github.com/roboll/helmfile) for helmfile
documentation.

A general helmfile example is found [here](https://github.com/roboll/helmfile/tree/master/examples)