#!/bin/sh


# Function to wait for database startup
function wait_for_startup() {
	for i in {120..0}; do
		got_value=$(echo "SELECT 1;" | mariadb -s 2> /dev/null) || true
		if [ "$got_value" = "1" ]; then
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


# For normal tests we use the mysql username/password
if [ "$CI" = "true" ]; then
    # Setup database credentials
    cat <<EOF > /root/.my.cnf
[mysql]
user=$MYSQL_USER
password=$MYSQL_PASSWORD
[mysqladmin]
user=$MYSQL_USER
password=$MYSQL_PASSWORD
EOF
fi

# For cluster testing as we create more than one database, we use root details
if [ "$CI" = "cluster-node1" -o "$CI" = "cluster-node2" -o "$CI" = "cluster-node3" ]; then
    # Setup database credentials
    cat <<EOF > /root/.my.cnf
[mysql]
user=root
password=$MYSQL_ROOT_PASSWORD
[mysqladmin]
user=root
password=$MYSQL_ROOT_PASSWORD
EOF
fi



# Wait for database startup
wait_for_startup

# Only create the database for normal tests and cluster node1
[ "$CI" != "true" -a "$CI" != "cluster-node1" ] && return

echo "CREATE TABLE testtable (id INT AUTO_INCREMENT PRIMARY KEY, value TEXT);" | mariadb -v testdb
echo "INSERT INTO testtable (value) VALUES ('SUCCESS');" | mariadb -v testdb
