# Poxtgres-XL Chart

[Postgres-XL](https://www.postgres-xl.org/) is an all-purpose fully ACID open source multi node scalable SQL database solution, based on [PostgreSQL](https://www.postgresql.org/).

This chart is based upon the wonderful docker postgres-xl docker image here: https://github.com/pavouk-0/postgres-xl-docker

### BETA

This chart is in beta. Any contributors welcome. 

# Components overview

SEE: https://www.postgres-xl.org/documentation/xc-overview-components.html

1. [ Gateway manager (GTM) ](https://www.postgres-xl.org/documentation/app-gtm.html) - Single pod Deployment - provides transaction management for the entire cluster.
1. Coordinator - Multi-pod StatefulSet - Database external connections entry point (i.e. where I connect my client to). They provide transparent concurrency and integrity of transactions globally. Applications can choose any Coordinator to connect to, they work together. Any Coordinator provides the same view of the database, with the same data, as if it was one PostgreSQL database. The data stored in the coordinator is part of the DB data and should be backed up.
1. Datanode - Multi-pod StatefulSet - All table data is stored here. A table may be replicated or distributed between datanodes. Since query work is done on the datanodes, the scale and capacity of the db will be determine by the number of datanodes.
1. Gateway Proxy (optional) - NOT YET IMPLEMENTED. 

# Chart values

[STS] = `datanodes` or `coordinators` or `proxies` or `gateway_manager`

### Global values

name | description | default value 
--- | --- | ---
image | the image to use | pavouk0/postgres-xl:XL_10_R1_1-6-g68c378f-4-g7a65119
envs | Additional envs to add to all pods | [null]
managers_port | the port to use in the gateway manager or proxies | 6666
postgres_port | the internal and external postgres port | 5432

### For any stateful set

name | description | default value 
--- | --- | ---
[STS].count | The total number of replicas, dose not apply to gtm | 1
[STS].resources | the main pod resources | Limits, GTM - 2Gi, 2 cpu; All others - 1Gi, 1 cpu
[STS].resources | the main pod resources | Limits, GTM - 2Gi, 2 cpu; All others - 1Gi, 1 cpu
[STS].pvc | The persistence volume claim for data storage. Use this value to set the internal database storage. Recommended for Coordinators and Gateway managers, 100Mi | [null]
[STS].addContainers | yaml inject to add more containers
[STS].volumes | yaml inject to add more volumes
[STS].volumeMounts | yaml inject to add more volume mounts
[STS].addVolumeClaims | yaml inject to add STS dependent volume claims. See [here] (https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/) for more info about these
[STS].thread_count | applies only to proxies, and is the proxy worker thread count | 3 

### Advanced overriding values (use with care)

#### Global

name | description | default value 
--- | --- | ---
homedir | the image home directory | /var/lib/postgresql 
overrideEnvs | a set of envs which re added after the chart core envs, and allows to override the chart. | [null]

#### For any stateful set

name | description
--- | --- | ---
[STS].injectMainContainerYaml | inject yaml into the main container.
[STS].injectSpecYaml | inject yaml into the template spec.
[STS].injectSTSyaml | inject yaml into the main STS spec.

# backup and restore

In order to keep to kubernetes principles, this helm chart allows to specify the persistent volume claim class for the workers, coordinators and gm. This data will persist between restarts. The persistent volumes created will be prefixed by `datastore-`

In the most general, in order to make a copy of the database one must copy all the data of each and every coordinator and data nods. This means that, when relaying on this type of persistence one must:

1. Create a backup solution using a specified [ persistent storage class](https://kubernetes.io/docs/concepts/storage/storage-classes/), and allow the backend to keep copies of the data between restarts. 
1. You CANNOT decrease the number of executing datanodes and coordinators otherwise data will be lost. Scaling up may require the redistribution of tables, information about such operations can be found [here]().

[ More about replication and high availability.](https://www.postgres-xl.org/documentation/different-replication-solutions.html)

### TODO: WAL restore using buckets @
1. GCS
2. AWS

# health check and status

For the current beta phase, a pod will be considered healthy if it can pass,
1. pg_isready.
2. Connect to the gtm, datanodes (all), coordinators (all).

# Some other notes

[Postgres-XL FAQ](https://www.postgres-xl.org/faq/)

Benchmarks:
1. https://www.2ndquadrant.com/en/blog/postgres-xl-scalability-for-loading-data/
1. https://www.2ndquadrant.com/en/blog/benchmarking-postgres-xl/

# Caveats

The data in the DB will presist only when all datanodes, coordinators and gm disks are safely restored. This helm 
chart dose not deal with partial restores.