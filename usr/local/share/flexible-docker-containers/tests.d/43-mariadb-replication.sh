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
		fdc_test_progress mariadb "Got\n$got_value"
		if [ "$got_value" = "$check" ]; then
			break
		fi
		fdc_test_progress mariadb "Waiting for correct value ('$database', '$table', '$column')... ${i}s"
		sleep 1
	done
	if [ "$i" = 0 ]; then
		fdc_test_fail mariadb "Database did not return correct value ('$database', '$table', '$column')\nResult: $got_value"
		return 1
	fi
	return
}


# We only run this test for repl nodes
if [ "$FDC_CI" != "repl-node1" ] && [ "$FDC_CI" != "repl-node2" ] && [ "$FDC_CI" != "repl-node3" ]; then
	return
fi

fdc_test_start mariadb "Testing database table value"
# Wait for success and touch passed file if it did
if ! wait_for_startup testdb testtable value SUCCESS; then
	fdc_test_fail mariadb "Detabase table value test failed"
	false
fi
fdc_test_pass mariadb "Database table value matches"
