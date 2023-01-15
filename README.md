[![pipeline status](https://gitlab.conarx.tech/containers/mariadb/badges/main/pipeline.svg)](https://gitlab.conarx.tech/containers/mariadb/-/commits/main)

# Container Information

[Container Source](https://gitlab.conarx.tech/containers/mariadb) - [GitHub Mirror](https://github.com/AllWorldIT/containers-mariadb)

This is the Conarx Containers MariaDB image, it provides the MariaDB database bundled with clustering support provided by Galera.

Additional features:
* Innodb buffer size configuration
* Query cache configuration
* Preloading of SQL into a new database apon creation
* Galera clustering with optional GTID support


# Mirrors

|  Provider  |  Repository                             |
|------------|-----------------------------------------|
| DockerHub  | allworldit/mariadb                      |
| Conarx     | registry.conarx.tech/containers/mariadb |



# Commercial Support

Commercial support is available from [Conarx](https://conarx.tech).



# General Environment Variables

Additional environment variables are available from...
* [Conarx Containers Alpine image](https://gitlab.conarx.tech/containers/alpine).

Environment variables were prefixed with `MYSQL_` to try retain as much compatibility to the official MariaDB and MySQL images as
possible.


## MYSQL_ROOT_PASSWORD

Optional root password for the MySQL database when its created. If not assigned, it will be automatically generated and output in
the logs.


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


## MYSQL_QUERY_CACHE_SIZE

Setup query caching with a query cache size in MBytes. eg. `MYSQL_QUERY_CACHE_SIZE=8`



# Volumes


## /var/lib/mysql

MariaDB data directory.



# Preloading SQL on Database Creation

## Directory: /var/lib/mysql-initdb.d

Any file in this directory with a .sql, .sql.gz, .sql.xz or .sql.zst extension will be loaded into the database apon initialization.



# Clustering

When using clustering the database credentials above and below MUST be the same across all nodes.

If you are moving the first node from a normal DB to a clustered setup you will need to create a `.create_sst_user` file in the
data directory for the sync user to be created.

```bash
touch data/var/lib/mysql/.create_sst_user
```

## Cluster settings

Environment variables can be set to configure the cluster.


### MYSQL_CLUSTER_JOIN

**This option will enable clustering**

Comma separated list of cluster nodes to join. The bare minimum configuration for this option is the value of `MYSQL_CLUSTER_NODE_NAME`
below.


### MYSQL_SST_PASSWORD

**Mandatory Option**

This must be specified, the default password used is `msyql.sst` which is not secure.


### MYSQL_CLUSTER_DEBUG

Enable database cluster debugging mode. eg. `MYSQL_CLUSTER_DEBUG=yes`


### MYSQL_CLUSTER_NAME

Optional name of the cluster.


### MYSQL_CLUSTER_NODE_NAME

Optional hostname of the node. Defaults to `hostname -f`.


### MYSQL_CLUSTER_NODE_IP

Optional IP address of the node. Defaults to the IP which `hostname -i` outputs.


### MYSQL_CLUSTER_NODE_PORT

Optional TCP/IP port of this node for cluster communication. Defaults to 3306.


## Cluster GTID Support


### MYSQL_CLUSTER_USE_GTID

Enable GTID support in the cluster.


### MYSQL_CLUSTER_GTID_LOCAL_ID

**Mandatory option for GTID**

This must be set to a globally unique node ID. It must not be the same as any MYSQL_CLUSTER_GTID_CLUSTER_ID.


### MYSQL_CLUSTER_GTID_CLUSTER_ID

**Mandatory option for GTID**

This must be set to a globally unique node ID. It must not be the same as any MYSQL_CLUSTER_GTID_LOCAL_ID.



## Bootstrapping a cluster

Should this be the first node starting up, create the data directory and touch the bootstrap file using the below...

```bash
mkdir -p data/var/lib/mysql
touch data/var/lib/mysql/.bootstrap-cluster
```

This will add `--wsrep-new-cluster` commandline option to the server and set this node as primary.

When a node is not the last one to leave a cluster, but needs to be the first one to startup, we need to further force this
behavior or the cluster will not start. For this one can use the below. This must be done in ADDITION to the above.

```bash
touch data/var/lib/mysql/.force-bootstrap-cluster
```



## Cluster Configuration Example

### Node 1

```bash
MYSQL_USER=testuser
MYSQL_PASSWORD=testpass
MYSQL_ROOT_PASSWORD=rootpass
MYSQL_DATABASE=testdb
# Cluster configuration
MYSQL_CLUSTER_NODE_NAME=node1
MYSQL_CLUSTER_JOIN=node1,node2,node3
# Optional GTID support
MYSQL_CLUSTER_USE_GTID=yes
MYSQL_CLUSTER_GTID_LOCAL_ID=10
MYSQL_CLUSTER_GTID_CLUSTER_ID=100
```

Initialize the data volume and set this node to force bootstrapping...
```bash
mkdir -p data/var/lib/mysql
touch data/var/lib/mysql/bootstrap-cluster
```


### Node 2

```bash
MYSQL_USER=testuser
MYSQL_PASSWORD=testpass
MYSQL_ROOT_PASSWORD=rootpass
MYSQL_DATABASE=testdb
# Cluster configuration
MYSQL_CLUSTER_NODE_NAME=node2
MYSQL_CLUSTER_JOIN=node1,node2,node3
# Optional GTID support
MYSQL_CLUSTER_USE_GTID=yes
MYSQL_CLUSTER_GTID_LOCAL_ID=20
MYSQL_CLUSTER_GTID_CLUSTER_ID=200
```
Initialize the data volume...
```bash
mkdir -p data/var/lib/mysql
```


### Node 3

```bash
MYSQL_USER=testuser
MYSQL_PASSWORD=testpass
MYSQL_ROOT_PASSWORD=rootpass
MYSQL_DATABASE=testdb
# Cluster configuration
MYSQL_CLUSTER_NODE_NAME=node3
MYSQL_CLUSTER_JOIN=node1,node2,node3
# Optional GTID support
MYSQL_CLUSTER_USE_GTID=yes
MYSQL_CLUSTER_GTID_LOCAL_ID=30
MYSQL_CLUSTER_GTID_CLUSTER_ID=300
```

Initialize the data volume...
```bash
mkdir -p data/var/lib/mysql
```
