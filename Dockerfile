
FROM registry.gitlab.iitsp.com/allworldit/docker/alpine:latest as builder


ENV MARIADB_VER=10.10.2
ENV GALERA_VER=26.4.12
ENV WSREP_VER=26


# Copy build patches
COPY patches build/patches


# Install libs we need
RUN set -ex; \
	true "Installing build dependencies"; \
# from https://git.alpinelinux.org/aports/tree/main/mariadb/APKBUILD
	apk add --no-cache \
		build-base \
		openssl-dev zlib-dev mariadb-connector-c-dev \
		\
		bison cmake curl-dev libaio-dev libarchive-dev libevent-dev \
		libxml2-dev ncurses-dev pcre2-dev readline-dev xz-dev linux-headers linux-pam-dev \
		samurai \
		\
		perl perl-dbi perl-dbd-mysql perl-getopt-long perl-socket perl-term-readkey \
		\
		boost-dev \
		bzip2-dev zstd-dev lz4-dev lzo-dev snappy-dev jemalloc-dev asio-dev check-dev


# Download packages
RUN set -ex; \
	mkdir -p build; \
	cd build; \
	wget "https://downloads.mariadb.org/interstitial/mariadb-${MARIADB_VER}/source/mariadb-${MARIADB_VER}.tar.gz"; \
	wget "https://github.com/codership/galera/archive/release_${GALERA_VER}.tar.gz" -O "galera-${GALERA_VER}.tar.gz"; \
	tar -xf "mariadb-${MARIADB_VER}.tar.gz"; \
	tar -xf "galera-${GALERA_VER}.tar.gz"

# Build and install MariaDB
RUN set -ex; \
	cd build; \
	cd mariadb-${MARIADB_VER}; \
# Compiler flags
	export CFLAGS="-march=x86-64 -mtune=generic -Os -pipe -fno-plt -fexceptions -Wp,-D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -fstack-clash-protection -fcf-protection -flto=auto"; \
	export CXXFLAGS="-Wp,-D_GLIBCXX_ASSERTIONS"; \
	export LDFLAGS="-Wl,-Os,--sort-common,--as-needed,-z,relro,-z,now -flto=auto"; \
	\
	source "VERSION"; \
	source ../galera-release_"${GALERA_VER}"/GALERA_VERSION; \
	MYSQL_VERSION="$MYSQL_VERSION_MAJOR.$MYSQL_VERSION_MINOR.$MYSQL_VERSION_PATCH"; \
	WSREP_VERSION="$(grep WSREP_INTERFACE_VERSION wsrep-lib/wsrep-API/v26/wsrep_api.h | cut -d '"' -f2).$(grep 'SET(WSREP_PATCH_VERSION'  "cmake/wsrep-.cmake" | cut -d '"' -f2)"; \
	GALERA_VERSION="$GALERA_VERSION_WSREP_API.$GALERA_VERSION_MAJOR.$GALERA_VERSION_MINOR$GALERA_VERSION_EXTRA"; \
	COMMENT="MariaDB Cluster $MYSQL_VERSION, WSREP version $WSREP_VERSION, Galera version $GALERA_VERSION"; \
	\
	pkgname=mariadb; \
	cmake . \
		-DBUILD_CONFIG=mysql_release \
		-DCMAKE_BUILD_TYPE=MinSizeRel \
		-DCMAKE_INSTALL_PREFIX=/usr \
		-DSYSCONFDIR=/etc \
		-DSYSCONF2DIR=/etc/my.cnf.d \
		-DMYSQL_DATADIR=/var/lib/mysql \
		-DMYSQL_UNIX_ADDR=/run/mysqld/mysqld.sock \
		-DDEFAULT_CHARSET=utf8mb4 \
		-DDEFAULT_COLLATION=utf8mb4_general_ci \
		-DENABLED_LOCAL_INFILE=ON \
		-DINSTALL_INFODIR=share/info \
		-DINSTALL_MANDIR=share/man \
		-DINSTALL_PLUGINDIR=lib/$pkgname/plugin \
		-DINSTALL_SCRIPTDIR=bin \
		-DINSTALL_INCLUDEDIR=include/mysql \
		-DINSTALL_DOCREADMEDIR=share/doc/$pkgname \
		-DINSTALL_SUPPORTFILESDIR=share/$pkgname \
		-DINSTALL_MYSQLSHAREDIR=share/$pkgname \
		-DINSTALL_DOCDIR=share/doc/$pkgname \
		-DTMPDIR=/var/tmp \
		-DCONNECT_WITH_MYSQL=ON \
		-DCONNECT_WITH_LIBXML2=system \
		-DCONNECT_WITH_ODBC=NO \
		-DCONNECT_WITH_JDBC=NO \
		-DPLUGIN_ARCHIVE=YES \
		-DPLUGIN_ARIA=YES \
		-DPLUGIN_BLACKHOLE=YES \
		-DPLUGIN_CASSANDRA=NO \
		-DPLUGIN_CSV=YES \
		-DPLUGIN_MYISAM=YES \
		-DPLUGIN_MROONGA=YES \
		-DPLUGIN_OQGRAPH=NO \
		-DPLUGIN_PARTITION=YES \
		-DPLUGIN_ROCKSDB=YES \
		-DPLUGIN_SPHINX=NO \
		-DPLUGIN_SPIDER=YES \
		-DPLUGIN_TOKUDB=NO \
		-DPLUGIN_AUTH_GSSAPI=NO \
		-DPLUGIN_AUTH_GSSAPI_CLIENT=OFF \
		-DPLUGIN_CRACKLIB_PASSWORD_CHECK=NO \
		-DWITH_ASAN=OFF \
#		-DWITH_EMBEDDED_SERVER=ON \
		-DWITH_EXTRA_CHARSETS=complex \
		-DWITH_INNODB_BZIP2=ON \
		-DWITH_INNODB_LZ4=ON \
		-DWITH_INNODB_LZMA=ON \
		-DWITH_INNODB_LZO=ON \
		-DWITH_INNODB_SNAPPY=ON \
		-DWITH_ROCKSDB_BZIP2=ON \
		-DWITH_ROCKSDB_JEMALLOC=ON \
		-DWITH_ROCKSDB_LZ4=ON \
		-DWITH_ROCKSDB_ZSTD=ON \
		-DWITH_ROCKSDB_SNAPPY=ON \
		-DWITH_JEMALLOC=ON \
		-DWITH_LIBARCHIVE=system \
		-DWITH_LIBNUMA=NO \
		-DWITH_LIBWRAP=OFF \
		-DWITH_LIBWSEP=OFF \
		-DWITH_MARIABACKUP=ON \
		-DWITH_PCRE=system \
		-DWITH_READLINE=ON \
		-DWITH_SYSTEMD=no \
		-DWITH_SSL=system \
		-DWITH_VALGRIND=OFF \
		-DWITH_ZLIB=system \
		-DSKIP_TESTS=ON \
		-DCOMPILATION_COMMENT="$COMMENT" \
		-DDEFAULT_CHARSET=utf8mb4 \
		-DDEFAULT_COLLATION=utf8mb4_unicode_520_ci \
		; \
	\
# Output build config
	cmake -L; \
	\
# Build
	make VERBOSE=1 -j$(nprocs); \
# Install
	pkgdir="/build/mariadb-root"; \
	DESTDIR="$pkgdir" cmake --install .; \
	\
	mkdir -p "$pkgdir"/etc/my.cnf.d; \
# Remove cruft
	find "$pkgdir" -type f -name "*.a" | xargs rm -fv; \
	rm -rfv \
		"$pkgdir"/usr/bin/mariadb_config \
		"$pkgdir"/usr/bin/mysql_config \
		"$pkgdir"/usr/include \
		"$pkgdir"/usr/lib/$pkgname/plugin/dialog.so \
		"$pkgdir"/usr/lib/$pkgname/plugin/mysql_clear_password.so \
		"$pkgdir"/usr/lib/$pkgname/plugin/sha256_password.so \
		"$pkgdir"/usr/lib/$pkgname/plugin/caching_sha2_password.so \
		"$pkgdir"/usr/lib/$pkgname/plugin/client_ed25519.so \
		"$pkgdir"/usr/lib/libmysqlclient.so \
		"$pkgdir"/usr/lib/libmysqlclient_r.so \
		"$pkgdir"/usr/lib/libmariadb.so* \
		"$pkgdir"/usr/lib/pkgconfig/libmariadb.pc \
		"$pkgdir"/usr/mysql-test \
		"$pkgdir"/usr/sql-bench \
		"$pkgdir"/usr/lib/pkgconfig


# Build and install Galera
RUN set -ex; \
	cd build; \
	cd galera-release_"${GALERA_VER}"; \
# Patch
	patch -p1 < ../patches/galera-musl-page-size.patch; \
	patch -p1 < ../patches/galera-musl-sched_param.patch; \
# 26.4.13
#	patch -p1 < ../patches/galera-musl-sys-poll-h.patch; \
	patch -p1 < ../patches/galera-musl-wordsize.patch; \
# Use MaraiDB's wsrep
	rmdir wsrep/src; \
	ln -s "../../mariadb-${MARIADB_VER}/wsrep-lib/wsrep-API/v${WSREP_VER}" wsrep/src; \
# Compiler flags
	export CFLAGS="-march=x86-64 -mtune=generic -Os -pipe -fno-plt -fexceptions -Wp,-D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -fstack-clash-protection -fcf-protection -flto=auto"; \
	export CXXFLAGS="-Wp,-D_GLIBCXX_ASSERTIONS"; \
	export LDFLAGS="-Wl,-Os,--sort-common,--as-needed,-z,relro,-z,now -flto=auto"; \
	\
# Build
	cmake .; \
	make VERBOSE=1 -j$(nprocs); \
# Install
	pkgdir="/build/mariadb-root"; \
	mkdir -p "$pkgdir"/usr/lib/galera; \
	install -m0755 libgalera_smm.so "$pkgdir"/usr/lib/galera/; \
	install -m0755 garb/garbd /usr/sbin/


RUN set -ex; \
	cd build/mariadb-root; \
	pkgdir="/build/mariadb-root"; \
	scanelf --recursive --nobanner --osabi --etype "ET_DYN,ET_EXEC" .  | awk '{print $3}' | xargs \
		strip \
			--remove-section=.comment \
			--remove-section=.note \
			-R .gnu.lto_* -R .gnu.debuglto_* \
			-N __gnu_lto_slim -N __gnu_lto_v1 \
			--strip-unneeded




FROM registry.gitlab.iitsp.com/allworldit/docker/alpine:latest

ARG VERSION_INFO=
LABEL maintainer="Nigel Kukard <nkukard@lbsd.net>"

# Copy in built binaries
COPY --from=builder /build/mariadb-root /


RUN set -ex; \
	true "Install requirements"; \
# NK: These are critical for some tools to work correctly
	apk add --no-cache coreutils rsync socat procps pv pwgen; \
	apk add --no-cache syslog-ng; \
	apk add --no-cache \
		libaio libssl3 libcrypto3 pcre2 snappy zstd-libs libxml2 nghttp2-libs ncurses-libs lzo xz-libs lz4-libs libcurl \
		libbz2 brotli-libs; \
	true "Setup user and group"; \
	addgroup -S mysql 2>/dev/null; \
	adduser -S -D -h /var/lib/mysql -s /sbin/nologin -G mysql -g mysql mysql 2>/dev/null; \
	true "Create initdb dirs"; \
	mkdir /docker-entrypoint-initdb.d; \
	chmod 750 /docker-entrypoint-initdb.d; \
	true "Versioning"; \
	if [ -n "$VERSION_INFO" ]; then echo "$VERSION_INFO" >> /.VERSION_INFO; fi; \
	true "Cleanup"; \
	rm -f /var/cache/apk/*

# Syslog-ng (for logging of syslog to stdout/stderr to docker)
COPY etc/syslog-ng/syslog-ng.conf /etc/syslog-ng/syslog-ng.conf
COPY etc/supervisor/conf.d/syslog-ng.conf /etc/supervisor/conf.d/syslog-ng.conf
RUN set -ex; \
	chown root:root \
		/etc/syslog-ng/syslog-ng.conf \
		/etc/supervisor/conf.d/syslog-ng.conf; \
	chmod 0644 \
		/etc/syslog-ng/syslog-ng.conf \
		/etc/supervisor/conf.d/syslog-ng.conf

# MariaDB
COPY etc/my.cnf /etc/my.cnf
COPY etc/my.cnf.d/docker.cnf /etc/my.cnf.d/docker.cnf
COPY etc/supervisor/conf.d/mariadb.conf /etc/supervisor/conf.d/mariadb.conf
COPY bin/mariadbd-starter /usr/bin/mariadbd-starter
COPY init.d/50-mariadb.sh /docker-entrypoint-init.d/50-mariadb.sh
COPY pre-init-tests.d/50-mariadb.sh /docker-entrypoint-pre-init-tests.d/50-mariadb.sh
COPY tests.d/50-mariadb.sh /docker-entrypoint-tests.d/50-mariadb.sh
RUN set -ex; \
	chown root:root \
		/etc/my.cnf \
		/etc/my.cnf.d/docker.cnf \
		/etc/supervisor/conf.d/mariadb.conf \
		/usr/bin/mariadbd-starter \
		/docker-entrypoint-init.d/50-mariadb.sh \
		/docker-entrypoint-pre-init-tests.d/50-mariadb.sh \
		/docker-entrypoint-tests.d/50-mariadb.sh; \
	chmod 0644 \
		/etc/my.cnf \
		/etc/my.cnf.d/docker.cnf \
		/etc/supervisor/conf.d/mariadb.conf; \
	chmod 0755 \
		/usr/bin/mariadbd-starter \
		/docker-entrypoint-init.d/50-mariadb.sh \
		/docker-entrypoint-pre-init-tests.d/50-mariadb.sh \
		/docker-entrypoint-tests.d/50-mariadb.sh

VOLUME ["/var/lib/mysql"]

EXPOSE 3306

