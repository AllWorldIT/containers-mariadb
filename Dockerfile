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


#
# We use a builder to build mariadb
#


FROM registry.conarx.tech/containers/alpine/3.17:latest as builder


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


# Download MariaDB and Galera tarballs
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
# Patching
	patch -p1 < ../patches/better-tmpdirs.patch; \
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
	make VERBOSE=1 -j$(nproc) -l 8; \
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
		"$pkgdir"/usr/share/man \
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
# NK: Below patch is for 26.4.13
#	patch -p1 < ../patches/galera-musl-sys-poll-h.patch; \
	patch -p1 < ../patches/galera-musl-wordsize.patch; \
# Remove for 26.4.13
	patch -p1 < ../patches/galera-memory-leak-fix.patch; \
# Use MaraiDB's wsrep
	rmdir wsrep/src; \
	ln -s "../../mariadb-${MARIADB_VER}/wsrep-lib/wsrep-API/v${WSREP_VER}" wsrep/src; \
# Compiler flags
	export CFLAGS="-march=x86-64 -mtune=generic -Os -pipe -fno-plt -fexceptions -Wp,-D_FORTIFY_SOURCE=2 -Wformat -Werror=format-security -fstack-clash-protection -fcf-protection -flto=auto"; \
	export CXXFLAGS="$CFLAGS -Wp,-D_GLIBCXX_ASSERTIONS"; \
	export LDFLAGS="-Wl,-Os,--sort-common,--as-needed,-z,relro,-z,now -flto=auto"; \
	\
# Build
	cmake .; \
	make VERBOSE=1 -j$(nprocs) -l 8; \
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



#
# Build the actual image
#


FROM registry.conarx.tech/containers/alpine/3.17:latest


ARG VERSION_INFO=
LABEL org.opencontainers.image.authors   = "Nigel Kukard <nkukard@conarx.tech>"
LABEL org.opencontainers.image.version   = "3.17"
LABEL org.opencontainers.image.base.name = "registry.conarx.tech/containers/alpine/3.17"


# Copy in built binaries
COPY --from=builder /build/mariadb-root /


RUN set -ex; \
	true "Install requirements"; \
# NK: These are critical for some tools to work correctly
	apk add --no-cache coreutils rsync socat procps pv pwgen; \
	apk add --no-cache \
		libaio libssl3 libcrypto3 pcre2 snappy zstd-libs libxml2 nghttp2-libs ncurses-libs lzo xz-libs lz4-libs libcurl \
		libbz2 brotli-libs; \
	true "Setup user and group"; \
	addgroup -S mysql 2>/dev/null; \
	adduser -S -D -h /var/lib/mysql -s /sbin/nologin -G mysql -g mysql mysql 2>/dev/null; \
	true "Create initdb dirs"; \
	mkdir /var/lib/mysql-initdb.d; \
	true "Cleanup"; \
	rm -f /var/cache/apk/*


# MariaDB
COPY etc/my.cnf /etc
COPY etc/my.cnf.d/10_fdc_defaults.cnf /etc/my.cnf.d
COPY etc/supervisor/conf.d/mariadb.conf /etc/supervisor/conf.d
COPY usr/local/sbin/start-mariadb /usr/local/sbin
COPY usr/local/share/flexible-docker-containers/init.d/42-mariadb.sh /usr/local/share/flexible-docker-containers/init.d
COPY usr/local/share/flexible-docker-containers/pre-init-tests.d/42-mariadb.sh /usr/local/share/flexible-docker-containers/pre-init-tests.d
COPY usr/local/share/flexible-docker-containers/healthcheck.d/42-mariadb.sh /usr/local/share/flexible-docker-containers/healthcheck.d
COPY usr/local/share/flexible-docker-containers/tests.d/42-mariadb.sh /usr/local/share/flexible-docker-containers/tests.d
COPY usr/local/share/flexible-docker-containers/tests.d/43-mariadb-cluster.sh /usr/local/share/flexible-docker-containers/tests.d
RUN set -ex; \
	true "Flexible Docker Containers"; \
	if [ -n "$VERSION_INFO" ]; then echo "$VERSION_INFO" >> /.VERSION_INFO; fi; \
	chown root:root \
		/etc/my.cnf \
		/etc/my.cnf.d/10_fdc_defaults.cnf \
		/var/lib/mysql-initdb.d \
		/usr/local/sbin/start-mariadb; \
	chmod 0644 \
		/etc/my.cnf \
		/etc/my.cnf.d/10_fdc_defaults.cnf; \
	chmod 0755 \
		/usr/local/sbin/start-mariadb; \
	chmod 750 \
		/var/lib/mysql-initdb.d; \
	fdc set-perms



VOLUME ["/var/lib/mysql"]

EXPOSE 3306
