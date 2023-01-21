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


# We apply the same settings to all instances regardless of the test we're running

fdc_notice "Setting up MariaDB CI test configuration..."

export MYSQL_USER=testuser
export MYSQL_PASSWORD=testpass
export MYSQL_ROOT_PASSWORD=rootpass
export MYSQL_DATABASE=testdb

# Check if we're doing a gtid-flavor cluster test
if [ "$FDC_CI" = "cluster-node1-gtid" ]; then
	export FDC_CI=cluster-node1
	export MYSQL_CLUSTER_USE_GTID=yes
	export MYSQL_CLUSTER_GTID_LOCAL_ID=10
	export MYSQL_CLUSTER_GTID_CLUSTER_ID=100
fi
if [ "$FDC_CI" = "cluster-node2-gtid" ]; then
	export FDC_CI=cluster-node2
	export MYSQL_CLUSTER_USE_GTID=yes
	export MYSQL_CLUSTER_GTID_LOCAL_ID=20
	export MYSQL_CLUSTER_GTID_CLUSTER_ID=200
fi
if [ "$FDC_CI" = "cluster-node3-gtid" ]; then
	export FDC_CI=cluster-node3
	export MYSQL_CLUSTER_USE_GTID=yes
	export MYSQL_CLUSTER_GTID_LOCAL_ID=30
	export MYSQL_CLUSTER_GTID_CLUSTER_ID=300
fi


if [ "$FDC_CI" = "cluster-node1" ]; then
	export MYSQL_CLUSTER_NODE_NAME=node1
	export MYSQL_CLUSTER_JOIN=node1,node2,node3
	export _MYSQL_CLUSTER_BOOTSTRAP=yes
	export _MYSQL_CLUSTER_BOOTSTRAP_FORCE=yes
fi

if [ "$FDC_CI" = "cluster-node2" ]; then
	export MYSQL_CLUSTER_NODE_NAME=node2
	export MYSQL_CLUSTER_JOIN=node1,node2,node3
	# NK: We need to stagger startups or we get duplicate uuid's ... wtf
	sleep 5
fi

if [ "$FDC_CI" = "cluster-node3" ]; then
	export MYSQL_CLUSTER_NODE_NAME=node3
	export MYSQL_CLUSTER_JOIN=node1,node2,node3
	# NK: We need to stagger startups or we get duplicate uuid's ... wtf
	sleep 10
fi
