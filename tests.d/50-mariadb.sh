#!/bin/sh

# Setup database credentials
cat <<EOF > /root/.my.cnf
[mysql]
user=$MYSQL_USER
password=$MYSQL_PASSWORD
[mysqladmin]
user=$MYSQL_USER
password=$MYSQL_PASSWORD
EOF


echo "CREATE TABLE testtable (id INT AUTO_INCREMENT PRIMARY KEY);" | mysql -v testdb


