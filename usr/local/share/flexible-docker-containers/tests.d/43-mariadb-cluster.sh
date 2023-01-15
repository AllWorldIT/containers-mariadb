#!/bin/bash
# Copyright (c) 2022-2023, AllWorldIT.
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
    database=$1
    table=$2
    column=$3
    check=$4

	for i in {240..0}; do
		got_value=$(echo "SELECT $column FROM $table" | mariadb -s "$database" 2>&1) || true
        echo "TEST PROGRESS (mariadb): Got\n$got_value"
		if [ "$got_value" = "$check" ]; then
			break
		fi
		echo "TEST PROGRESS (mariadb): Waiting for correct value ('$database', '$table', '$column')... ${i}s"
		sleep 1
	done
	if [ "$i" = 0 ]; then
		echo -e "TEST FAILED (mariadb): Database did not return correct value ('$database', '$table', '$column')\nResult: $got_value"
		return 1
	fi
    return
}


# We only run this test for cluster nodes
[ "$FDC_CI" != "cluster-node1" -a "$FDC_CI" != "cluster-node2" -a "$FDC_CI" != "cluster-node3" ] && return

echo "TEST START (mariadb): Testing default setup"
# Wait for success and touch passed file if it did
if wait_for_startup testdb testtable value SUCCESS; then
    echo "TEST PASSED (mariadb): Contents for testdb is correct"
else
    false
fi


# If we have GTID enabled, check its set to ON
if [ -n "$MYSQL_CLUSTER_USE_GTID" ]; then
    echo "TEST START (mariadb): Testing GTID is enabled"
    gtid_support=$(echo "SHOW GLOBAL VARIABLES WHERE Variable_name = 'wsrep_gtid_mode'" | mariadb -s 2>/dev/null | awk '{ print $2 }' || true )
    if [ "$gtid_support" != "ON" ]; then
        echo "TEST FAILED (mariadb): GTID support does not seem to be enabled! result='$gtid_support'"
        exit 1
    fi
    echo "TEST PASSED (mariadb): GTID is enabled!"
fi


# Next, on node2, create another database and table to test
echo "TEST START (mariadb): Testing cluster-node2"
if [ "$FDC_CI" = "cluster-node2" ]; then
    echo "TEST PROGRESS (mariadb): Setting up cluster-node2 database 'testdb2' and table 'testtable'"
    echo "CREATE DATABASE testdb2" | mariadb -v
    echo "CREATE TABLE testtable (id INT AUTO_INCREMENT PRIMARY KEY, value TEXT);" | mariadb -v testdb2
    echo "INSERT INTO testtable (value) VALUES ('SUCCESS');" | mariadb -v testdb2
fi
# Wait for success and touch passed file if it did
if wait_for_startup testdb2 testtable value SUCCESS; then
    echo "TEST PASSED (mariadb): Database contents from cluster-node2 for testdb2 is correct"
else
    false
fi



# Next, on node3, create another database and table to test
echo "TEST START (mariadb): Testing cluster-node3"
if [ "$FDC_CI" = "cluster-node3" ]; then
    echo "TEST PROGRESS (mariadb): Setting up cluster-node3 database 'testdb3' and table 'testtable'"
    echo "CREATE DATABASE testdb3" | mariadb -v
    echo "CREATE TABLE testtable (id INT AUTO_INCREMENT PRIMARY KEY, value TEXT);" | mariadb -v testdb3
    echo "INSERT INTO testtable (value) VALUES ('SUCCESS');" | mariadb -v testdb3
fi
# Wait for success and touch passed file if it did
if wait_for_startup testdb3 testtable value SUCCESS; then
    echo "TEST PASSED (mariadb): Database contents from cluster-node3 for testdb3 is correct"
else
    false
fi



echo "PASSED" > /PASSED_MARIADB

echo "NOTICE: Done with MariaDB testing, waiting for shutdown"
sleep 600
