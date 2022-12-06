# Introduction

This is a MariaDB container.

See the [Alpine Base Image](https://gitlab.iitsp.com/allworldit/docker/alpine) project for additional configuration.

# MariaDB

The following directories can be mapped in:

## Directory: /docker-entrypoint-initdb.d

Any file in this directory with a .sql, .sql.gz, .sql.xz or .sql.zst extension will be loaded into the database apon initialization.

## Volume: /var/lib/mysql

Data directory.

## MYSQL_ROOT_PASSWORD

Optional root password for the MySQL database when its created. If not assigned, it will be automatically generated and output in the logs.

## MYSQL_DATABASE

Optional database to create.

## MYSQL_USER

Optional user to create for the MySQL database. It will be granted access to the `MYSQL_DATABASE` database.

## MYSQL_PASSWORD

Optional password to set for `MYSQL_USER`.


## MYSQL_CHARSET

Optional character set for the database. Deafults to `utf8mb4`.

## MYSQL_COLLATION

Optional collation for the database. Deafults to `uca1400_as_ci`.


## MYSQL_BUFFER_SIZE

Should be set to 60% of the available memory.

eg. `MYSQL_BUFFER_SIZE=200M`



# Caching


## MYSQL_QUERY_CACHE_SIZE: optional

Query cache size in MBytes.




# Clustering


When using clustering the credentials above and below MUST be the same across all nodes.

If you are moving the first node from a normal DB to a clustered setup you can create the `.create_sst_user` file in the
data directory.

```bash
touch data/var/lib/mysql/.create_sst_user
```

## Cluster settings

Environment variables can be set to configure the cluster.

### MYSQL_ENABLE_CLUSTERING: mandatory

Set this to any value to enable clustering. eg. ENABLE_CLUSTERING=yes


### MYSQL_SST_PASSWORD: mandatory

This must be specified, the default password used is `msyql.sst` which is not secure.


### MYSQL_CLUSTER_DEBUG: optional

Enable debugging mode. eg. MYSQL_CLUSTER_DEBUG=yes


### MYSQL_CLUSTER_NAME: optional

Optional name of the cluster.


### MYSQL_NODE_NAME: optional

Optional hostname of the node. Defaults to `hostname -f`.


### MYSQL_NODE_IP: optional

Optional IP address of the node. Defaults to the IP which `hostname -i` outputs.


### MYSQL_NODE_PORT: optional

Optional TCP/IP port of this node for cluster communication. Defaults to 3306.


### MYSQL_CLUSTER_JOIN: optional

Comma separated list of cluster nodes to join.


## Cluster GTID Support

### MYSQL_CLUSTER_USE_GTID: optional

Enable GTID support in the cluster.

### MYSQL_CLUSTER_GTID_LOCAL_ID: mandatory

This must be set to a globally unique node ID. It must not be the same as any MYSQL_CLUSTER_GTID_CLUSTER_ID.

### MYSQL_CLUSTER_GTID_CLUSTER_ID: mandatory

This must be set to a globally unique node ID. It must not be the same as any MYSQL_CLUSTER_GTID_LOCAL_ID.



## Bootstrapping a cluster

Should this be the first node starting up, create the data directory and touch the bootstrap file using the below...

```bash
mkdir -p data/var/lib/mysql
touch data/var/lib/mysql/bootstrap-cluster
```

This will add `--wsrep-new-cluster` commandline option to the server and set this node as primary.

WARNING!! There is a environment variable `CLUSTER_BOOTSTRAP` which can be used, this is generally only used for testing purposes
as it would be dangerous to have the service process exit and re-execute while bootstrapping.

When a node is not the last one to leave a cluster, but needs to be the first one to startup, we need to further force this
behavior or the cluster will not start. For this one can use the below. This must be done in ADDITION to the above.

```bash
touch data/var/lib/mysql/force-bootstrap-cluster
```

WARNING!! For testing purposes we also have environment variable `CLUSTER_BOOTSTRAP_FORCE`.



# Replication

