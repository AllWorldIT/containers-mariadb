#!/bin/sh


# Function to wait for database startup
function wait_for_startup() {
	# if [ -n "$CLUSTER_JOIN" ]; then
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
		echo "INFO: Database starting... ${i}s"
		sleep 1
	done
	if [ "$i" = 0 ]; then
		echo "ERROR: Database start failed!"
		exit 1
	fi
}

# Function to wait for database to shutdown
function wait_for_shutdown() {
	for i in {120..0}; do
		if ! kill -s 0 "$1" &> /dev/null; then
			break
		fi
		echo "INFO: Waiting for database shutdown to continue with startup... ${i}s"
		sleep 1
	done
	if [ "$i" = 0 ]; then
		echo "ERROR: Database failed shutdown!"
		exit 1
	fi
}




if [ ! -d "/run/mysqld" ]; then
	mkdir -p /run/mysqld
fi
chown -R mysql:mysql /run/mysqld

if [ ! -d "/var/tmp/mysqld" ]; then
	mkdir -p /var/tmp/mysqld/sst
fi
chown -R mysql:mysql /var/tmp/mysqld
chmod 0750 /var/tmp/mysqld


# Tuning
if [ -n "$MYSQL_BUFFER_SIZE" ]; then
	perl -pi -e "s/innodb-buffer-pool-size=.*/innodb-buffer-pool-size=$MYSQL_BUFFER_SIZE/" /etc/my.cnf.d/docker.cnf
fi

if [ -d /var/lib/mysql/mysql ]; then
	chown -R mysql:mysql /var/lib/mysql
else
	echo "NOTICE: Data directory not found, initializing..."

	chown -R mysql:mysql /var/lib/mysql

	mariadb-install-db --user=mysql --ldata=/var/lib/mysql > /dev/null

	# Write current version info to file so we can do an upgrade if required later
	mariadbd --version > /var/lib/mysql/version_info

	if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
		MYSQL_ROOT_PASSWORD=`pwgen 16 1`
		echo "NOTICE: MariaDB root Password: $MYSQL_ROOT_PASSWORD"
	fi

	MYSQL_DATABASE=${MYSQL_DATABASE:-""}
	MYSQL_USER=${MYSQL_USER:-""}
	MYSQL_PASSWORD=${MYSQL_PASSWORD:-""}

	tfile=`mktemp`
	if [ ! -f "$tfile" ]; then
		return 1
	fi

	cat << EOF > "$tfile"
SET @@SESSION.SQL_LOG_BIN=0;
FLUSH PRIVILEGES;
USE mysql;
GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION;
GRANT ALL ON *.* TO 'root'@'localhost' IDENTIFIED VIA unix_socket WITH GRANT OPTION;
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
EOF

	# Trigger SST user creation
	[ -n "$ENABLE_CLUSTERING" ] && touch /var/lib/mysql/.create_sst_user

	if [ -n "$MYSQL_DATABASE" ]; then
		echo "NOTICE: Creating database: $MYSQL_DATABASE"
		if [ -n "$MYSQL_CHARSET" ] && [ -n "$MYSQL_COLLATION" ]; then
			echo "INFO: Character set [$MYSQL_CHARSET] and collation [$MYSQL_COLLATION]"
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET $MYSQL_CHARSET COLLATE $MYSQL_COLLATION;" >> "$tfile"
		else
			echo "INFO: Character set [utf8mb4] and collation [utf8mb4_unicode_520_ci]"
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci;" >> "$tfile"
		fi

		if [ -n "$MYSQL_USER" ]; then
			echo "NOTICE: Creating user [$MYSQL_USER] with password [$MYSQL_PASSWORD]"
			echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" >> "$tfile"
			echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';" >> "$tfile"
		fi
	fi

	mariadbd --user=mysql --bootstrap --skip-networking=1 < "$tfile"
	rm -f "$tfile"

	find /docker-entrypoint-initdb.d -type f | sort | while read f
	do
		case "$f" in
			*.sql)    echo "NOTICE: initdb.d - Loading [$f]"; mariadbd --user=mysql --bootstrap --verbose=0 --skip-networking=1 < "$f"; echo ;;
			*.sql.gz) echo "NOTICE: initdb.d - Loading [$f]"; gunzip -c "$f" | mariadbd --user=mysql --bootstrap --verbose=0 --skip-networking=1; echo ;;
			*.sql.xz) echo "NOTICE: initdb.d - Loading [$f]"; unxz -c "$f" | mariadbd --user=mysql --bootstrap --verbose=0 --skip-networking=1; echo ;;
			*.sql.zst) echo "NOTICE: initdb.d - Loading [$f]"; unzstd -c "$f" | mariadbd --user=mysql --bootstrap --verbose=0 --skip-networking=1; echo ;;
			*)        echo "WARNING: Ignoring initdb entry [$f]" ;;
		esac
	done
fi



#
# Query Cache
#

if [ -n "$MYSQL_QUERY_CACHE_SIZE" ]; then
	query_cache_size=$((MYSQL_QUERY_CACHE_SIZE * 1024 * 1024))
	echo "[mariadb]" > /etc/my.cnf.d/query-cache.cnf
	echo "query_cache_size = $query_cache_size" >> /etc/my.cnf.d/query-cache.cnf
fi



#
# Clustering
#

if [ -n "$ENABLE_CLUSTERING" ]; then
	echo "INFO: Setting up cluster"

	# Configure the cluster
	CLUSTER_CONF_FILE=/etc/my.cnf.d/cluster.cnf
	CLUSTER_PRIVCONF_FILE=/etc/my.cnf.d/cluster-private.cnf

	MYSQL_SST_PASSWORD=${MYSQL_SST_PASSWORD:-"mariadb.sst"}


	#
	# Cluster configuration
	#

	if [ -z "${NODE_NAME}" ]; then
		NODE_NAME=$(hostname -f)
	fi

	if [ -z "${NODE_IP}" ]; then
		NODE_IP=$(hostname -i)
	fi

	if [ -z "${NODE_PORT}" ]; then
		NODE_PORT=3306
	fi

	echo "[sst]" > "$CLUSTER_CONF_FILE"
	echo "tmpdir = /var/tmp/mysqld/sst" >> "$CLUSTER_CONF_FILE"

	echo "[mariadb]" >> "$CLUSTER_CONF_FILE"

	echo "wsrep_on = ON" >> "$CLUSTER_CONF_FILE"

	echo "binlog_format= 'ROW'" >> "$CLUSTER_CONF_FILE"

	if [ -n "${CLUSTER_NAME}" ]; then
		echo "wsrep_cluster_name = ${CLUSTER_NAME}" >> "$CLUSTER_CONF_FILE"
	fi

	echo "wsrep_node_name = ${NODE_NAME}" >> "$CLUSTER_CONF_FILE"
	echo "wsrep_node_address = ${NODE_IP}" >> "$CLUSTER_CONF_FILE"

	if [ -z "${CLUSTER_JOIN}" ]; then
		CLUSTER_JOIN="$NODE_NAME"
	fi
	echo "wsrep_cluster_address = gcomm://${CLUSTER_JOIN}" >> "$CLUSTER_CONF_FILE"

	if [ -n "$CLUSTER_DEBUG" ]; then
		echo "wsrep_debug = ON" >> "$CLUSTER_CONF_FILE"
	fi
	echo "wsrep_provider_options = gmcast.listen_addr=tcp://[::]:4567" >> "$CLUSTER_CONF_FILE"

	# We need to make sure that the "mysql" user exists as this is used for SST
	if [ -e /var/lib/mysql/.create_sst_user ]; then

		cat <<EOF | mariadbd --user=mysql --bootstrap --verbose=0 --skip-networking=1
SET @@SESSION.SQL_LOG_BIN=0;
FLUSH PRIVILEGES;
DROP USER IF EXISTS 'mariadb.sst'@'localhost';
GRANT RELOAD, PROCESS, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'mariadb.sst'@'localhost' IDENTIFIED BY '$MYSQL_SST_PASSWORD';
SET PASSWORD FOR 'mariadb.sst'@'localhost'=PASSWORD('${MYSQL_SST_PASSWORD}');
FLUSH PRIVILEGES;
EOF
		rm -f /var/lib/mysql/.create_sst_user
	fi

	# Setup authentication details for SST
	echo "[mariadb]" > "$CLUSTER_PRIVCONF_FILE"
	echo "wsrep_sst_auth = mariadb.sst:$MYSQL_SST_PASSWORD" >> "$CLUSTER_PRIVCONF_FILE"


	#
	# GTID
	#

	if [ -n "$CLUSTER_USE_GTID" ]; then

		if [ -z "$CLUSTER_GTID_LOCAL_ID" ]; then
			echo "ERROR: For a GTID enabled cluster, environment variable 'CLUSTER_GTID_LOCAL_ID' must be provided"
			exit 1
		fi

		if [ -z "$CLUSTER_GTID_CLUSTER_ID" ]; then
			echo "ERROR: For a GTID enabled cluster, environment variable 'CLUSTER_GTID_CLUSTER_ID' must be provided"
			exit 1
		fi

		echo "wsrep_gtid_mode = ON" >> "$CLUSTER_CONF_FILE"
		echo "wsrep_gtid_domain_id = ${CLUSTER_GTID_LOCAL_ID}" >> "$CLUSTER_CONF_FILE"
		echo "gtid_domain_id = ${CLUSTER_GTID_CLUSTER_ID}" >> "$CLUSTER_CONF_FILE"
		echo "log_bin = ON" >> "$CLUSTER_CONF_FILE"
		echo "log_slave_updates = ON" >> "$CLUSTER_CONF_FILE"
	fi


	#
	# Bootstrapping
	#

	# We need to trigger bootstrapping if we've got the env defined
	if [ -n "$CLUSTER_BOOTSTRAP" ]; then
		echo "NOTICE: Triggering cluster bootstrap"
		touch /var/lib/mysql/bootstrap-cluster
		# Check if we really need to force bootstrapping
		if [ -n "$CLUSTER_BOOTSTRAP_FORCE" ]; then
			echo "NOTICE: Triggering cluster bootstrap FORCE"
			touch /var/lib/mysql/force-bootstrap-cluster
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

	echo "INFO: Cluster setup done"
fi


#
# Database upgrade
#

# Check if we need to do a database update
DB_VERSION_OLD=$([ -e /var/lib/mysql/mysql_upgrade_info ] && cat /var/lib/mysql/mysql_upgrade_info || :)
DB_VERSION_NEW=$(mariadbd --version | awk '{ print $3 }')

if [ -n "$DB_VERSION_OLD" -a "${DB_VERSION_OLD%-log}" != "${DB_VERSION_NEW%-log}" ]; then
	echo "NOTICE: Database needs updating"
	echo "NOTICE:   - old: $DB_VERSION_OLD"
	echo "NOTICE:   - new: $DB_VERSION_NEW"

	echo "NOTICE: Updating database..."

	# Start database
	mariadbd --user=mysql --skip-networking --wsrep-provider=none &
	mariadb_pid=$!
	wait_for_startup

	# Do upgrade
	mariadb-upgrade --skip-write-binlog
	echo "SHUTDOWN;" | mariadb

	# Stop database
	wait_for_shutdown "$mariadb_pid"

	rm -f /root/.my.cnf
fi
