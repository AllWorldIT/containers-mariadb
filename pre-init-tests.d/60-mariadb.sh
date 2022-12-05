#!/bin/sh

# We apply the same settings to all instances regardless of the test we're running

echo "NOTICE: Setting up CI test configuration..."

export MYSQL_USER=testuser
export MYSQL_PASSWORD=testpass
export MYSQL_ROOT_PASSWORD=rootpass
export MYSQL_DATABASE=testdb

# Check if we're doing a gtid-flavor cluster test
if [ "$CI" = "cluster-node1-gtid" ]; then
    export CI=cluster-node1
    export MYSQL_CLUSTER_ENABLE_GTID=yes
    export MYSQL_CLUSTER_GTID_LOCAL_ID=10
    export MYSQL_CLUSTER_GTID_CLUSTER_ID=100
fi
if [ "$CI" = "cluster-node2-gtid" ]; then
    export CI=cluster-node2
    export MYSQL_CLUSTER_ENABLE_GTID=yes
    export MYSQL_CLUSTER_GTID_LOCAL_ID=20
    export MYSQL_CLUSTER_GTID_CLUSTER_ID=200
fi
if [ "$CI" = "cluster-node3-gtid" ]; then
    export CI=cluster-node3
    export MYSQL_CLUSTER_ENABLE_GTID=yes
    export MYSQL_CLUSTER_GTID_LOCAL_ID=30
    export MYSQL_CLUSTER_GTID_CLUSTER_ID=300
fi


if [ "$CI" = "cluster-node1" ]; then
    export MYSQL_ENABLE_CLUSTERING=yes
    export MYSQL_CLUSTER_NODE_NAME=node1
    export MYSQL_CLUSTER_JOIN=node1,node2,node3
    export MYSQL_CLUSTER_BOOTSTRAP=yes
    export MYSQL_CLUSTER_BOOTSTRAP_FORCE=yes
fi

if [ "$CI" = "cluster-node2" ]; then
    export MYSQL_ENABLE_CLUSTERING=yes
    export MYSQL_CLUSTER_NODE_NAME=node2
    export MYSQL_CLUSTER_JOIN=node1,node2,node3
    # NK: We need to stagger startups or we get duplicate uuid's ... wtf
    sleep 5
fi

if [ "$CI" = "cluster-node3" ]; then
    export MYSQL_ENABLE_CLUSTERING=yes
    export MYSQL_CLUSTER_NODE_NAME=node3
    export MYSQL_CLUSTER_JOIN=node1,node2,node3
    # NK: We need to stagger startups or we get duplicate uuid's ... wtf
    sleep 10
fi
