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
	for i in {240..0}; do
		got_value=$(echo "SELECT 1;" | mariadb -s 2>&1) || true
		echo "TEST PROGRESS (mariadb): Got\n$got_value"
		if [ "$got_value" = "1" ]; then
			break
		fi
		echo "TEST PROGRESS (mariadb): Waiting for database start... ${i}s"
		sleep 1
	done
	if [ "$i" = 0 ]; then
		echo "TEST FAILED (mariadb): Database start failed!"
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
if [ "$FDC_CI" = "cluster-node1" -o "$FDC_CI" = "cluster-node2" -o "$FDC_CI" = "cluster-node3" ]; then
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
echo "TEST START (mariadb): Wait for startup..."
wait_for_startup
echo "TEST PASSED (mariadb): Database started"

# Only create the database for normal tests and cluster node1
[ "$FDC_CI" != "true" -a "$FDC_CI" != "cluster-node1" ] && return

echo "TEST START (mariadb): Test create table..."
echo "CREATE TABLE testtable (id INT AUTO_INCREMENT PRIMARY KEY, value TEXT);" | mariadb -v testdb
echo "TEST PASSED (mariadb): Test table created"

echo "TEST START (mariadb): Test insert into table..."
echo "INSERT INTO testtable (value) VALUES ('SUCCESS');" | mariadb -v testdb
echo "TEST PASSED (mariadb): Test insert done"
