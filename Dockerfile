FROM registry.gitlab.iitsp.com/allworldit/docker/alpine:latest

ARG VERSION_INFO=
LABEL maintainer="Nigel Kukard <nkukard@lbsd.net>"

RUN set -ex; \
	true "MariaDB"; \
	apk add --no-cache mariadb mariadb-client mariadb-server-utils pwgen; \
	true "MariaDB"; \
	mkdir /docker-entrypoint-initdb.d; \
	chmod 750 /docker-entrypoint-initdb.d; \
	true "Versioning"; \
	if [ -n "$VERSION_INFO" ]; then echo "$VERSION_INFO" >> /.VERSION_INFO; fi; \
	true "Cleanup"; \
	rm -f /var/cache/apk/*

# MariaDB
COPY etc/my.cnf.d/docker.cnf /etc/my.cnf.d/docker.cnf
COPY etc/supervisor/conf.d/mariadb.conf /etc/supervisor/conf.d/mariadb.conf
COPY init.d/50-mariadb.sh /docker-entrypoint-init.d/50-mariadb.sh
COPY pre-init-tests.d/50-mariadb.sh /docker-entrypoint-pre-init-tests.d/50-mariadb.sh
COPY tests.d/50-mariadb.sh /docker-entrypoint-tests.d/50-mariadb.sh
RUN set -ex; \
		chown root:root \
			/etc/my.cnf.d/docker.cnf \
			/etc/supervisor/conf.d/mariadb.conf \
			/docker-entrypoint-init.d/50-mariadb.sh \
			/docker-entrypoint-pre-init-tests.d/50-mariadb.sh \
			/docker-entrypoint-tests.d/50-mariadb.sh; \
		chmod 0644 \
			/etc/my.cnf.d/docker.cnf \
			/etc/supervisor/conf.d/mariadb.conf; \
		chmod 0755 \
			/docker-entrypoint-init.d/50-mariadb.sh \
			/docker-entrypoint-pre-init-tests.d/50-mariadb.sh \
			/docker-entrypoint-tests.d/50-mariadb.sh

VOLUME ["/var/lib/mysql"]

EXPOSE 3306

