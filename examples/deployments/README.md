# Example deployments

The examples in this directory are of simple, value change, deployments 
of the database. 

The examples use the tool [helmfile]() to deploy the chart onto a cluster.

# Resources

The resources chosen in these examples are specifically low to allow these examples to be tested on local machines. Recommended values for nodes can be found in the main README file.

# Helmfile, in (very) short

Allows for deploying helm releases, given either a directory or a repo url.
See examples above for postgres-xl, or [here](https://github.com/roboll/helmfile) for helmfile
documentation.

A general helmfile example is found [here](https://github.com/roboll/helmfile/tree/master/examples)