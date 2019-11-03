# Example deployments

The examples in this directory are of simple, value change, deployments 
of the database. 

The examples use the tool [helmfile](https://github.com/roboll/helmfile) to deploy the chart onto a cluster.

# Running using helmfile

### Requirements
1. `helm` installed
1. `helmfile` installed.

### Steps
1. Clone the repo
1. Travel to your example folder.
1. Run `helmfile sync`

Note: if security is enabled on your cluster, please contact the cluster/helm admin.

# Resources

The resources chosen in these examples are specifically low to allow 
these examples to be tested on local machines. Recommended values for nodes 
can be found in the main README file.

# Helmfile, in (very) short

Allows for deploying helm releases, given either a directory or a repo url.
See examples above for postgres-xl, or [here](https://github.com/roboll/helmfile) for helmfile
documentation.

A general helmfile example is found [here](https://github.com/roboll/helmfile/tree/master/examples)