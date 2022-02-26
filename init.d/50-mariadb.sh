#!/bin/sh

if [ -d "/run/mysqld" ]; then
	chown -R mysql:mysql /run/mysqld
else
	mkdir -p /run/mysqld
	chown -R mysql:mysql /run/mysqld
fi

# Tuning
if [ -n "$MYSQL_BUFFER_SIZE" ]; then
	perl -pi -e "s/innodb-buffer-pool-size=.*/innodb-buffer-pool-size=$MYSQL_BUFFER_SIZE/" /etc/my.cnf.d/docker.cnf
fi

if [ -d /var/lib/mysql/mysql ]; then
	chown -R mysql:mysql /var/lib/mysql
else
	echo "NOTICE: Data directory not found, initializing"

	chown -R mysql:mysql /var/lib/mysql

	mysql_install_db --user=mysql --ldata=/var/lib/mysql > /dev/null

	if [ "$MYSQL_ROOT_PASSWORD" = "" ]; then
		MYSQL_ROOT_PASSWORD=`pwgen 16 1`
		echo "NOTICE: MySQL root Password: $MYSQL_ROOT_PASSWORD"
	fi

	MYSQL_DATABASE=${MYSQL_DATABASE:-""}
	MYSQL_USER=${MYSQL_USER:-""}
	MYSQL_PASSWORD=${MYSQL_PASSWORD:-""}

	tfile=`mktemp`
	if [ ! -f "$tfile" ]; then
		return 1
	fi

	cat << EOF > "$tfile"
USE mysql;
FLUSH PRIVILEGES ;
GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION ;
GRANT ALL ON *.* TO 'root'@'localhost' IDENTIFIED BY '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION ;
SET PASSWORD FOR 'root'@'localhost'=PASSWORD('${MYSQL_ROOT_PASSWORD}') ;
DROP DATABASE IF EXISTS test ;
FLUSH PRIVILEGES ;
EOF

	if [ "$MYSQL_DATABASE" != "" ]; then
		echo "NOTICE: Creating database: $MYSQL_DATABASE"
		if [ "$MYSQL_CHARSET" != "" ] && [ "$MYSQL_COLLATION" != "" ]; then
			echo "INFO: Character set [$MYSQL_CHARSET] and collation [$MYSQL_COLLATION]"
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET $MYSQL_CHARSET COLLATE $MYSQL_COLLATION;" >> "$tfile"
		else
			echo "INFO: Character set [utf8] and collation [utf8_general_ci]"
			echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> "$tfile"
		fi

		if [ "$MYSQL_USER" != "" ]; then
			echo "NOTICE: Creating user [$MYSQL_USER] with password [$MYSQL_PASSWORD]"
			echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" >> "$tfile"
			echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'localhost' IDENTIFIED BY '$MYSQL_PASSWORD';" >> "$tfile"
		fi
	fi

	/usr/bin/mysqld --user=mysql --bootstrap --verbose=0 --skip-networking=1 < "$tfile"
	rm -f $tfile

	find /docker-entrypoint-initdb.d -type f | while read f
	do
		case "$f" in
			*.sql)    echo "NOTICE: initdb.d - Loading [$f]"; /usr/bin/mysqld --user=mysql --bootstrap --verbose=0 --skip-networking=1 < "$f"; echo ;;
			*.sql.gz) echo "NOTICE: initdb.d - Loading [$f]"; gunzip -c "$f" | /usr/bin/mysqld --user=mysql --bootstrap --verbose=0 --skip-networking=1 < "$f"; echo ;;
			*.sql.xz) echo "NOTICE: initdb.d - Loading [$f]"; unxz -c "$f" | /usr/bin/mysqld --user=mysql --bootstrap --verbose=0 --skip-networking=1 < "$f"; echo ;;
			*.sql.zst) echo "NOTICE: initdb.d - Loading [$f]"; unzstd -c "$f" | /usr/bin/mysqld --user=mysql --bootstrap --verbose=0 --skip-networking=1 < "$f"; echo ;;
			*)        echo "WARNING: Ignoring initdb entry [$f]" ;;
		esac
	done
fi


