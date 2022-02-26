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

Optional character set for the database. Deafults to `utf8`.

## MYSQL_COLLATION

Optional collation for the database. Deafults to `utf8_general_ci`.


## MYSQL_BUFFER_SIZE

Should be set to 60% of the available memory.

eg. `MYSQL_BUFFER_SIZE=200M`

