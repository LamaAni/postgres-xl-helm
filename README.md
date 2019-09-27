# Postgres-XL Chart

[Postgres-XL](https://www.postgres-xl.org/) is an all-purpose fully ACID open source multi node scalable SQL database solution, based on [PostgreSQL](https://www.postgresql.org/).

This chart allows for creating a multi container, multi process, distributed database using Postgres-XL. It is based upon the wonderful docker postgres-xl docker image here: https://github.com/pavouk-0/postgres-xl-docker, where you can also find a graph description of the cluster configuration.

#### Important note
If using this chart as a database, please make sure you read the sections about persistence, backup and restore. 

### BETA

This chart is in beta. Any contributors welcome. 

# Components overview

SEE: https://www.postgres-xl.org/documentation/xc-overview-components.html

1. [ Gateway manager (GTM) ](https://www.postgres-xl.org/documentation/app-gtm.html) - Single pod StatefulSet - provides transaction management for the entire cluster. The data stored in the GTM is part of the database persistence and should be backed up.
1. Coordinator - Multi-pod StatefulSet - Database external connections entry point (i.e. where I connect my client to). These pods provide transparent concurrency and integrity of transactions globally. Applications can choose any Coordinator to connect to, they work together. Any Coordinator provides the same view of the database, with the same data, as if it was one PostgreSQL database. The data stored in the coordinator is part of the DB data and should be backed up.
1. Datanode - Multi-pod StatefulSet - All table data is stored here. A table may be replicated or distributed between datanodes. Since query work is done on the datanodes, the scale and capacity of the db will be determine by the number of datanodes. The data stored in the coordinator is part of the DB data and should be backed up.
1. Gateway Proxy (optional) - A helper gateway manager. Gtm proxy groups connections and interactions between gtm and other Postgres-XL components to reduce both the number of interactions and the size of messages. Performance tests have shown greater performance with high concurrency workloads as a result.

To connect to the database, please connect to the db main service (which is the coordinator service), example:
```shell
kubectl port-forward svc/[release-name]-postgres-xl-svc
```

# Chart values

[STS] = `datanodes` or `coordinators` or `proxies` or `gateway_manager`

Example: datanodes.count = 32

### Global values

name | description | default value 
--- | --- | ---
image | the image to use | pavouk0/postgres-xl:XL_10_R1_1-6-g68c378f-4-g7a65119
envs | Additional envs to add to all pods | [null]
managers_port | the port to use in the gateway manager or proxies | 6666
postgres_port | the internal and external postgres port | 5432
service.port | the external service port | 5432
service.enabled | if true enables the external load balancer service | true
service.type | The external service type | LoadBalancer

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
[STS].addVolumeClaims | yaml inject to add STS dependent volume claims. See [here](https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/) for more info about these
[STS].thread_count | applies only to proxies, and is the proxy worker thread count | 3 

### Advanced overriding values (use with care)

#### Global

name | description | default value 
--- | --- | ---
homedir | the image home directory | /var/lib/postgresql 
overrideEnvs | a set of envs which are added after the chart core envs, and allows to override the chart. | [null]
service.injectSpecYaml | injects yaml into the external service | [null]

#### For any stateful set

name | description
--- | ---
[STS].injectMainContainerYaml | inject yaml into the main container.
[STS].injectSpecYaml | inject yaml into the template spec.
[STS].injectSTSYaml | inject yaml into the main STS spec.

# Persistence

The implementation in this chart relies on StatefulSets to maintain data persistence between recoveries and restarts.
To do so, one must define the `pvc` argument in the values. If you do not define the `pvc` argument, the 
data `will be lost` on any case of restart/recover/fail.

To define a persistent database you must define all three `pvc`s for each of the stateful sets,
(below are recommended test values, where x is the size of each datanode)
```yaml
datanodes.pvc:
  resources:
      requests:
        storage: [x]Gi
gateway_manager.pvc:
  resources:
      requests:
        storage: 100Mi
coordinators.pvc:
  resources:
      requests:
        storage: 100Mi
```

Once these are defined, the DB will recover when any of datanode/coordinator/proxy/gm are restarted.

See more about persistence in Stateful Sets [here](https://kubernetes.io/docs/tutorials/stateful-application/basic-stateful-set/)
and [here](https://kubernetes.io/docs/concepts/storage/persistent-volumes/).

# Backup and restore

In order to keep to kubernetes principles, this helm chart allows to specify the persistent volume claim class for the workers, coordinators and gm. This data will persist between restarts. The persistent volumes created will be prefixed by `datastore-`

Information about StorageClasses can be found [here](https://kubernetes.io/docs/concepts/storage/volumes/)

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

The data in the DB will persist only when all datanodes, coordinators and gm disks are safely restored. This helm 
chart dose not deal with partial restores.

# Licence

Copyright ©
`Zav Shotan` and other [contributors](https://github.com/LamaAni/PGXL-HELM/graphs/contributors).
It is free software, released under the MIT licence, and may be redistributed under the terms specified in `LICENSE`.