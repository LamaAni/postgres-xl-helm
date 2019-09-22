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



# backup and restore

In order to keep to kubernetes principles, this helm chart allows to specify the persistent volume claim class for the workers and nodes. This data will persist between restarts. The persistent volumes created will be prefixed by `datastore-`

In the most general, in order to make a copy of the database one must copy all the data of each and every coordinator and data nods. This means that, when relaying on this type of persistence one must:

1. Create a backup solution using a specified [ persistent storage class](https://kubernetes.io/docs/concepts/storage/storage-classes/), and allow the backend to keep copies of the data between restarts. 
1. You CANNOT decrease the number of executing datanodes and coordinators otherwise data will be lost. Scaling up may require the redistribution of tables, information about such operations can be found [here]().

[ More about replication and high availability.](https://www.postgres-xl.org/documentation/different-replication-solutions.html)

### TODO: WAL restore using buckets @
1. GCS
2. AWS

# health check and status

For the current chart, a pod will be considered healthy if it can pass,
1. pg_isready.
2. Connect to the gtm, datanodes (all), coordinators (all).

# Some other notes

[Postgres-XL FAQ](https://www.postgres-xl.org/faq/)

Benchmarks:
1. https://www.2ndquadrant.com/en/blog/postgres-xl-scalability-for-loading-data/
1. https://www.2ndquadrant.com/en/blog/benchmarking-postgres-xl/

Pros:
1. Its a distributed implementation of PostgresSQL, and is fully saleable for large datasets.
1. Can distribute the tables between various worker nodes for faster processing, where some of the distribution methods are automatic (ROUNDROBIN, By PrimaryKey, REPLICATION)

Cons:
1. The total number of nodes, after adding data to the 