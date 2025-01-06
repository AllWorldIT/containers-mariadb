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
	for i in {240..0}; do
		got_value=$(echo "SELECT 1;" | mariadb -s 2>&1) || true
		fdc_test_progress mariadb "Got\n$got_value"
		if [ "$got_value" = "1" ]; then
			break
		fi
		fdc_test_progress mariadb "Waiting for database start... ${i}s"
		sleep 1
	done
	if [ "$i" = 0 ]; then
		fdc_test_fail mariadb "Database start failed!"
		return 1
	fi
	return
}


# For normal tests we use the mysql username/password
if [ "$FDC_CI" = "true" ]; then
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
if [ "$FDC_CI" = "cluster-node1" ] || [ "$FDC_CI" = "cluster-node2" ] || [ "$FDC_CI" = "cluster-node3" ]; then
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
fdc_test_start mariadb "Wait for startup"
wait_for_startup
fdc_test_pass mariadb "Database started"

if [ "$FDC_CI" = "repl-node1" ]; then
	fdc_test_start mariadb "Dump base database"
	if ! mariadb-dump --single-transaction --master-data --gtid "$MYSQL_DATABASE" > /root/dump.sql; then
		fdc_test_fail mariadb "Failed to dump base database"
		false
	fi
	fdc_test_pass mariadb "Base database dumped"
fi

touch /READY_MARIADB

# Only create the database for normal tests and cluster node1
if [ "$FDC_CI" != "true" ] && [ "$FDC_CI" != "cluster-node1" ] && [ "$FDC_CI" != "repl-node1" ]; then
	return
fi

fdc_test_start mariadb "Test create table"
if ! echo "CREATE TABLE testtable (id INT AUTO_INCREMENT PRIMARY KEY, value TEXT);" | mariadb -v testdb; then
	fdc_test_fail mariadb "Failed to create table"
	false
fi
fdc_test_pass mariadb "Test table created"

fdc_test_start mariadb "Test insert into table"
if ! echo "INSERT INTO testtable (value) VALUES ('SUCCESS');" | mariadb -v testdb; then
	fdc_test_fail mariadb "Failed to insert into table"
	false
fi
fdc_test_pass mariadb "Test insert done"
