#!/bin/bash
# Copyright (c) 2022-2025, AllWorldIT.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.


# Function to wait for database startup
function wait_for_startup() {
	# if [ -n "$MYSQL_CLUSTER_JOIN" ]; then
	# 	check_select="SELECT variable_value FROM performance_schema.global_status WHERE variable_name='wsrep_local_state_comment'"
	# 	check_value="Synced"
	# else
		check_select="SELECT 1"
		check_value="1"
	# fi

	for i in {120..0}; do
		got_value=$(echo "$check_select" | mariadb -s 2> /dev/null) || true
		if [ "$got_value" = "$check_value" ]; then
			break
		fi
		fdc_info "MariaDB database starting... ${i}s"
		sleep 1
	done
	if [ "$i" = 0 ]; then
		fdc_error "MariaDB database start failed!"
		return 1
	fi
	return
}

# Function to wait for database to shutdown
function wait_for_shutdown() {
	for i in {120..0}; do
		if ! kill -s 0 "$1" &> /dev/null; then
			break
		fi
		fdc_info "Waiting for MariaDB database shutdown to continue with startup... ${i}s"
		sleep 1
	done
	if [ "$i" = 0 ]; then
		fdc_error "MariaDB database shutdown failed!"
		return 1
	fi
	return
}


# Setup directories
fdc_notice "Setting up MariaDB directories"
if [ ! -d "/run/mysqld" ]; then
	mkdir -p /run/mysqld
fi
chown -R mysql:mysql /run/mysqld

if [ ! -d "/var/tmp/mariadb" ]; then
	mkdir -p /var/tmp/mariadb
fi
chown -R mysql:mysql /var/tmp/mariadb
chmod 0750 /var/tmp/mariadb
chown -R mysql:mysql /var/lib/mysql


# Tuning
if [ -n "$MYSQL_BUFFER_SIZE" ]; then
	fdc_notice "Setting MariaDB 'innodb-buffer-pool-size' to $MYSQL_BUFFER_SIZE"
	sed -i -e "s/innodb-buffer-pool-size=.*/innodb-buffer-pool-size=$MYSQL_BUFFER_SIZE/" /etc/my.cnf.d/10_fdc_defaults.cnf
fi


if [ -d /var/lib/mysql/mysql ]; then
	fdc_notice "Existing MariaDB database found, continuing..."

else
	fdc_notice "Existing MaraiDB database not found, initializing..."

	mariadb-install-db --user=mysql --ldata=/var/lib/mysql > /dev/null

	# Write current version info to file so we can do an upgrade if required later
	mariadbd --version > /var/lib/mysql/version_info

	if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
		MYSQL_ROOT_PASSWORD=$(pwgen 16 1)
		fdc_notice "MariaDB 'root' password set to random '$MYSQL_ROOT_PASSWORD'"
	fi

	MYSQL_DATABASE=${MYSQL_DATABASE:-""}
	MYSQL_USER=${MYSQL_USER:-""}
	MYSQL_PASSWORD=${MYSQL_PASSWORD:-""}

	tfile=$(mktemp)
	if [ ! -f "$tfile" ]; then
		fdc_error "Temporary file '$tfile' does not exist after create"
		false
	fi

	cat << EOF > "$tfile"
SET @@SESSION.SQL_LOG_BIN=0;
FLUSH PRIVILEGES;
USE mysql;
GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION;
GRANT ALL ON *.* TO 'root'@'localhost' IDENTIFIED VIA unix_socket WITH GRANT OPTION;
DELETE FROM user WHERE User = '';
DROP DATABASE IF EXISTS test;
EOF

	# Trigger SST user creation
	[ -n "$MYSQL_CLUSTER_JOIN" ] && touch /var/lib/mysql/.create_sst_user

	if [ -n "$MYSQL_DATABASE" ]; then
		fdc_notice "Creating MariaDB database: $MYSQL_DATABASE"
		if [ -n "$MYSQL_CHARSET" ] && [ -n "$MYSQL_COLLATION" ]; then
			fdc_info "  - Character set [$MYSQL_CHARSET] and collation [$MYSQL_COLLATION]"
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET $MYSQL_CHARSET COLLATE $MYSQL_COLLATION;" >> "$tfile"
		else
			fdc_info "  - Character set [utf8mb4] and collation [utf8mb4_unicode_520_ci]"
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci;" >> "$tfile"
		fi

		if [ -n "$MYSQL_USER" ]; then
			fdc_notice "  - Creating user [$MYSQL_USER] with password"
			echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" >> "$tfile"
			echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';" >> "$tfile"
		fi
	fi

	mariadbd --user=mysql --bootstrap --skip-networking=1 < "$tfile"
	rm -f "$tfile"

	find /var/lib/mysql-initdb.d -type f | sort -n | while read -r f
	do
		case "$f" in
			*.sql)
				fdc_notice "mysql-initdb.d - Loading [$f]..."
				mariadbd --user=mysql --bootstrap --verbose=0 --skip-networking=1 < "$f"
				fdc_notice "mysql-initdb.d - Load done [$f]"
				;;
			*.sql.gz)
				fdc_notice "mysql-initdb.d - Loading [$f]..."
				gunzip -c "$f" | mariadbd --user=mysql --bootstrap --verbose=0 --skip-networking=1
				fdc_notice "mysql-initdb.d - Load done [$f]"
				;;
			*.sql.xz)
				fdc_notice "mysql-initdb.d - Loading [$f]..."
				unxz -c "$f" | mariadbd --user=mysql --bootstrap --verbose=0 --skip-networking=1
				fdc_notice "mysql-initdb.d - Load done [$f]"
				;;
			*.sql.zst)
				fdc_notice "mysql-initdb.d - Loading [$f]..."
				unzstd -c "$f" | mariadbd --user=mysql --bootstrap --verbose=0 --skip-networking=1
				fdc_notice "mysql-initdb.d - Load done [$f]"
				;;
			*)
				fdc_warn "mysql-initdb.d - Ignoring [$f], unsupported file extension"
				;;
		esac
	done
fi



#
# Query Cache
#

if [ -n "$MYSQL_QUERY_CACHE_SIZE" ]; then
	fdc_notice "Setting MariaDB 'query_cache_size' to ${MYSQL_QUERY_CACHE_SIZE}MiB"
	query_cache_size=$((MYSQL_QUERY_CACHE_SIZE * 1024 * 1024))
	echo "[mariadb]" > /etc/my.cnf.d/query-cache.cnf
	echo "query_cache_size = $query_cache_size" >> /etc/my.cnf.d/query-cache.cnf
fi


# Make sure only one replication mode is active
if [ -n "$MYSQL_REPLICATION_MASTER" ] && [ -n "$MYSQL_CLUSTER_JOIN" ]; then
	fdc_error "MariaDB cannot be both a replication master and a cluster node"
	false
fi


#
# Replication
#
if [ -n "$MYSQL_REPLICATION_ID" ]; then
	fdc_notice "Setting up MariaDB replication..."

	REPLICATION_CONF_FILE=/etc/my.cnf.d/replication.cnf

	fdc_notice "Setting replication ID set to $MYSQL_REPLICATION_ID"
	# Configure the replication
	{
		echo "[mariadb]"
		echo "server_id = $MYSQL_REPLICATION_ID"
		echo "gtid_domain_id = $MYSQL_REPLICATION_ID"
		echo "log-bin = ON"
		echo "log-basename = primary1"
		echo "binlog-format = mixed"
		echo "expire_logs_days = 7"
		echo "binlog_do_db = $MYSQL_DATABASE"
		echo "replicate_do_db = $MYSQL_DATABASE"
	} > "$REPLICATION_CONF_FILE"

	# Configure replication user
	if [ -n "$MYSQL_REPLICATION_USER" ]; then
		if [ -z "$MYSQL_REPLICATION_PASSWORD" ]; then
			fdc_error "For a MariaDB replication master, environment variable 'MYSQL_REPLICATION_PASSWORD' must be provided"
			false
		fi
		fdc_notice "Setting up MariaDB replication user '$MYSQL_REPLICATION_USER'"
		cat <<EOF | mariadbd --user=mysql --bootstrap --verbose=0 --skip-networking=1
SET @@SESSION.SQL_LOG_BIN=0;
FLUSH PRIVILEGES;
USE mysql;
GRANT REPLICATION SLAVE ON *.* TO '$MYSQL_REPLICATION_USER'@'%';
SET PASSWORD FOR '$MYSQL_REPLICATION_USER'@'%' = PASSWORD('$MYSQL_REPLICATION_PASSWORD');
EOF
	fi
else
	fdc_info "MariaDB not running in replication mode"
fi


#
# Clustering
#

if [ -n "$MYSQL_CLUSTER_JOIN" ]; then
	fdc_notice "Setting up MariaDB cluster..."

	# Configure the cluster
	CLUSTER_CONF_FILE=/etc/my.cnf.d/cluster.cnf
	CLUSTER_PRIVCONF_FILE=/etc/my.cnf.d/cluster-private.cnf

	MYSQL_SST_PASSWORD=${MYSQL_SST_PASSWORD:-"mariadb.sst"}


	#
	# Cluster configuration
	#

	if [ -z "$MYSQL_CLUSTER_NODE_NAME" ]; then
		MYSQL_CLUSTER_NODE_NAME=$(hostname -f)
	fi

	if [ -z "$MYSQL_CLUSTER_NODE_IP" ]; then
		MYSQL_CLUSTER_NODE_IP=$(hostname -i)
	fi

	if [ -z "$NODE_PORT" ]; then
		MYSQL_CLUSTER_NODE_PORT=4567
	fi

	{
		echo "[mariadb]"
		echo "wsrep_on = ON"
		echo "wsrep_provider = /opt/mariadb/lib/galera/libgalera_smm.so"
		echo "wsrep_sst_method = mariabackup"
		echo "binlog_format= ROW"

		if [ -n "${MYSQL_CLUSTER_NAME}" ]; then
			echo "wsrep_cluster_name = $MYSQL_CLUSTER_NAME"
		fi

		echo "wsrep_node_name = $MYSQL_CLUSTER_NODE_NAME"
		echo "wsrep_node_address = $MYSQL_CLUSTER_NODE_IP:$MYSQL_CLUSTER_NODE_PORT"
		echo "wsrep_cluster_address = gcomm://$MYSQL_CLUSTER_JOIN"

		if [ -n "$MYSQL_CLUSTER_DEBUG" ]; then
			echo "wsrep_debug = 1"
		fi

		echo "wsrep_provider_options = gmcast.listen_addr=tcp://[::]:4567" >> "$CLUSTER_CONF_FILE"
	}  >> "$CLUSTER_CONF_FILE"

	# We need to make sure that the "mysql" user exists as this is used for SST
	if [ -e /var/lib/mysql/.create_sst_user ]; then

		cat <<EOF | mariadbd --user=mysql --bootstrap --verbose=0 --skip-networking=1
SET @@SESSION.SQL_LOG_BIN=0;
FLUSH PRIVILEGES;
DROP USER IF EXISTS 'mariadb.sst'@'localhost';
GRANT RELOAD, PROCESS, LOCK TABLES, BINLOG MONITOR, REPLICA MONITOR, REPLICATION CLIENT, SLAVE MONITOR ON *.* TO 'mariadb.sst'@'localhost' IDENTIFIED BY '$MYSQL_SST_PASSWORD';
SET PASSWORD FOR 'mariadb.sst'@'localhost'=PASSWORD('$MYSQL_SST_PASSWORD');
EOF
		rm -f /var/lib/mysql/.create_sst_user
	fi

	# Setup authentication details for SST
	echo "[mariadb]" > "$CLUSTER_PRIVCONF_FILE"
	echo "wsrep_sst_auth = mariadb.sst:$MYSQL_SST_PASSWORD" >> "$CLUSTER_PRIVCONF_FILE"


	#
	# GTID
	#

	if [ -n "$MYSQL_CLUSTER_USE_GTID" ]; then
		fdc_notice "MariaDB enabling GTID support"

		if [ -z "$MYSQL_CLUSTER_GTID_LOCAL_ID" ]; then
			fdc_error "For a MariaDB GTID enabled cluster, environment variable 'MYSQL_CLUSTER_GTID_LOCAL_ID' must be provided"
			false
		fi

		if [ -z "$MYSQL_CLUSTER_GTID_CLUSTER_ID" ]; then
			fdc_error "For a MariaDB GTID enabled cluster, environment variable 'MYSQL_CLUSTER_GTID_CLUSTER_ID' must be provided"
			false
		fi

		{
			echo "wsrep_gtid_mode = ON"
			echo "wsrep_gtid_domain_id = $MYSQL_CLUSTER_GTID_LOCAL_ID"
			echo "gtid_domain_id = $MYSQL_CLUSTER_GTID_CLUSTER_ID"
			echo "log_bin = ON"
			echo "log_slave_updates = ON"
		} >> "$CLUSTER_CONF_FILE"
	fi


	#
	# Bootstrapping
	#

	# We need to trigger bootstrapping if we've got the env defined
	if [ -n "$_MYSQL_CLUSTER_BOOTSTRAP" ]; then
		fdc_notice "MariaDB triggering cluster bootstrap"
		touch /var/lib/mysql/.bootstrap-cluster
		# Check if we really need to force bootstrapping
		if [ -n "$_MYSQL_CLUSTER_BOOTSTRAP_FORCE" ]; then
			fdc_notice "MariaDB triggering cluster bootstrap - FORCED"
			touch /var/lib/mysql/.force-bootstrap-cluster
		fi
	fi


	#
	# Permissions
	#

	# If we have a private configuration file, set the perms
	if [ -e "$CLUSTER_PRIVCONF_FILE" ]; then
		chmod 0640 "$CLUSTER_PRIVCONF_FILE"
		chown root:mysql "$CLUSTER_PRIVCONF_FILE"
	fi

	fdc_info "MariaDB cluster setup done"
else
	fdc_info "MariaDB not running in cluster"
fi


# Write out /root/.my.cnf with root password for below and healthcheck
cat <<EOF > /root/.my.cnf
[client]
password=$MYSQL_ROOT_PASSWORD
EOF


#
# Database upgrade
#

# Check if we need to do a database update
DB_VERSION_OLD=$( if [ -e /var/lib/mysql/mysql_upgrade_info ]; then cat /var/lib/mysql/mysql_upgrade_info; fi )
DB_VERSION_NEW=$(mariadbd --version | awk '{ print $3 }')

if [ -n "$DB_VERSION_OLD" ] && [ "${DB_VERSION_OLD%-log}" != "${DB_VERSION_NEW%-log}" ]; then
	fdc_notice "MariaDB database needs upgrading..."
	fdc_notice "  - old version: $DB_VERSION_OLD"
	fdc_notice "  - new version: $DB_VERSION_NEW"

	fdc_notice "Upgrading MariaDB database..."

	# Start database
	mariadbd --user=mysql --skip-networking --wsrep-provider=none &
	mariadb_pid=$!
	wait_for_startup

	# Do upgrade
	mariadb-upgrade --skip-write-binlog
	echo "SHUTDOWN;" | mariadb

	# Stop database
	wait_for_shutdown "$mariadb_pid"
fi
