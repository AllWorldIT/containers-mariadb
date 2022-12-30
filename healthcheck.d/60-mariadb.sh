#!/bin/bash

if ! MARIADB_TEST_RESULT=$(mariadb-admin ping 2>&1); then
    echo -e "ERROR: Healthcheck failed for MariaDB:\n$MARIADB_TEST_RESULT"
    false
fi
if [ -n "$CI" ]; then
    echo -e "INFO: Healthcheck for MariaDB:\n$MARIADB_TEST_RESULT"
fi
