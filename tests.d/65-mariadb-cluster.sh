#!/bin/sh

# Function to wait for database startup
function wait_for_success() {
    database=$1
    table=$2
    column=$3
    check=$4

	for i in {120..0}; do
		got_value=$(echo "SELECT $column FROM $table" | mariadb -s "$database" 2> /dev/null) || true
		if [ "$got_value" = "$check" ]; then
			break
		fi
		echo "INFO: Waiting for correct value ('$database', '$table', '$column')... ${i}s"
		sleep 1
	done
	if [ "$i" = 0 ]; then
		echo "ERROR: Database did not return correct value!"
		return 1
	fi
    return 0
}


# We only run this test for cluster nodes
[ "$CI" != "cluster-node1" -a "$CI" != "cluster-node2" -a "$CI" != "cluster-node3" ] && return

echo "NOTICE: Testing default setup"
# Wait for success and touch passed file if it did
if wait_for_success testdb testtable value SUCCESS; then
    echo "NOTICE: Database content for testdb is correct, tests passed!"
    touch /var/lib/mysql/MARIADB_CI_PASSED1
fi


# If we have GTID enabled, check its set to ON
if [ -n "$MYSQL_CLUSTER_USE_GTID" ]; then
    gtid_support=$(echo "SHOW GLOBAL VARIABLES WHERE Variable_name = 'wsrep_gtid_mode'" | mariadb -s 2>/dev/null || true)
    if [ "$gtid_support" != "wsrep_gtid_mode ON" ]; then
        echo "ERROR: GTID support does not seem to be enabled! result='$gtid_support'"
        exit 1
    fi
fi


# Next, on node2, create another database and table to test
if [ "$CI" = "cluster-node2" ]; then
    echo "NOTICE: Setting up node2 database and table"
    echo "CREATE DATABASE testdb2" | mariadb -v
    echo "CREATE TABLE testtable (id INT AUTO_INCREMENT PRIMARY KEY, value TEXT);" | mariadb -v testdb2
    echo "INSERT INTO testtable (value) VALUES ('SUCCESS');" | mariadb -v testdb2
fi
# Wait for success and touch passed file if it did
if wait_for_success testdb2 testtable value SUCCESS; then
    echo "NOTICE: Database content for testdb2 is correct, tests passed!"
    touch /var/lib/mysql/MARIADB_CI_PASSED2
fi



# Next, on node3, create another database and table to test
if [ "$CI" = "cluster-node3" ]; then
    echo "NOTICE: Setting up node3 database and table"
    echo "CREATE DATABASE testdb3" | mariadb -v
    echo "CREATE TABLE testtable (id INT AUTO_INCREMENT PRIMARY KEY, value TEXT);" | mariadb -v testdb3
    echo "INSERT INTO testtable (value) VALUES ('SUCCESS');" | mariadb -v testdb3
fi
# Wait for success and touch passed file if it did
if wait_for_success testdb3 testtable value SUCCESS; then
    echo "NOTICE: Database content for testdb3 is correct, tests passed!"
    touch /var/lib/mysql/MARIADB_CI_PASSED3
fi


echo "NOTICE: Waiting for shutdown"
sleep 600
