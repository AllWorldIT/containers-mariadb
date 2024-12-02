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


FROM registry.conarx.tech/containers/alpine/edge as builder


# NB: Must be updated below too in image version
ENV MARIADB_VER=10.11.10
ENV MARIADB_BRANCH=10.11
ENV MARIADB_COMMIT=3d0fb150289716ca75cd64d62823cf715ee47646

ENV WSREP_VER=26

# https://github.com/MariaDB/galera/tree/mariadb-4.x-26.4.20
ENV GALERA_VER=26.4.20
ENV GALERA_BRANCH=mariadb-4.x-26.4.20
ENV GALERA_COMMIT=987e5f17ef4a396d06fba29b6785bef01edfd926


# Copy build patches
COPY patches build/patches


# Install libs we need
RUN set -eux; \
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
		bzip2-dev zstd-dev lz4-dev lzo-dev snappy-dev jemalloc-dev asio-dev check-dev fmt-dev \
		\
		git


# Download MariaDB and Galera tarballs
RUN set -eux; \
	mkdir -p build; \
	cd build; \
	# Clone MariaDB
	git clone  --verbose --branch "${MARIADB_BRANCH}" \
		https://github.com/MariaDB/server.git "mariadb-${MARIADB_VER}"; \
	cd "mariadb-${MARIADB_VER}"; \
	git checkout "${MARIADB_COMMIT}"; \
	git submodule update --jobs 8 --init --recursive --recommend-shallow; \
	cd ..; \
	# Clone Galera
	git clone --verbose --branch "${GALERA_BRANCH}" \
		https://github.com/MariaDB/galera.git "galera-${GALERA_VER}"; \
	cd "galera-${GALERA_VER}"; \
	git checkout "${GALERA_COMMIT}"


# Build and install MariaDB
RUN set -eux; \
	cd build; \
	cd mariadb-${MARIADB_VER}; \
	# Patching
	#patch -p1 < ../patches/mariadb-11.4.2_disable-failing-test.patch; \
	patch -p1 < ../patches/mariadb-11.4.2_gcc13.patch; \
	patch -p1 < ../patches/mariadb-11.4.2_have_stacktrace.patch; \
	#patch -p1 < ../patches/mariadb-11.4.2_lfs64.patch; \
	patch -p1 < ../patches/mariadb-10.11.7_lfs64.patch; \
	\
	patch -p1 < ../patches/mariadb-11.4.2_nk-fix-poll-h.patch; \
	\
	# Compiler flags
	. /etc/buildflags; \
	\
	WSREP_VERSION="$(grep WSREP_INTERFACE_VERSION wsrep-lib/wsrep-API/v26/wsrep_api.h | cut -d '"' -f2).$(grep 'SET(WSREP_PATCH_VERSION'  "cmake/wsrep-.cmake" | cut -d '"' -f2)"; \
	COMMENT="MariaDB $MARIADB_VER ($MARIADB_BRANCH/$MARIADB_COMMIT), WSREP version $WSREP_VERSION, Galera version $GALERA_VER ($GALERA_BRANCH/$GALERA_COMMIT)"; \
	# Configure
	pkgname=mariadb; \
	cmake -B build -G Ninja -Wno-dev \
		-DCMAKE_BUILD_TYPE=RelWithDebInfo \
		-DCMAKE_INSTALL_PREFIX=/opt/mariadb \
		-DCOMPILATION_COMMENT="Conarx Containers - $COMMENT" \
		-DSYSCONFDIR=/etc \
		-DSYSCONF2DIR=/etc/my.cnf.d \
		-DMYSQL_DATADIR=/var/lib/mysql \
		-DINSTALL_UNIX_ADDRDIR=/run/mysqld/mysqld.sock \
		-DDEFAULT_CHARSET=utf8mb4 \
		-DDEFAULT_COLLATION=utf8mb4_general_ci \
		-DENABLED_LOCAL_INFILE=ON \
		-DINSTALL_INFODIR=share/info \
		-DINSTALL_MANDIR=share/man \
		-DINSTALL_PAMDIR=/lib/security \
		-DINSTALL_PLUGINDIR=lib/$pkgname/plugin \
		-DINSTALL_SCRIPTDIR=bin \
		-DINSTALL_INCLUDEDIR=include/mysql \
		-DINSTALL_DOCREADMEDIR=share/doc/$pkgname \
		-DINSTALL_SUPPORTFILESDIR=share/$pkgname \
		-DINSTALL_MYSQLSHAREDIR=share/$pkgname \
		-DINSTALL_DOCDIR=share/doc/$pkgname \
		-DTMPDIR=/var/tmp/mariadb \
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
		-DPLUGIN_MROONGA=NO \
		-DPLUGIN_OQGRAPH=NO \
		-DPLUGIN_PARTITION=NO \
		-DPLUGIN_ROCKSDB=YES \
		-DPLUGIN_SPHINX=NO \
		-DPLUGIN_TOKUDB=NO \
		-DPLUGIN_AUTH_GSSAPI=NO \
		-DPLUGIN_AUTH_GSSAPI_CLIENT=OFF \
		-DPLUGIN_CRACKLIB_PASSWORD_CHECK=NO \
		-DWITH_ASAN=OFF \
		-DWITH_EMBEDDED_SERVER=OFF \
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
		-DWITH_LIBFMT=system \
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
		; \
	\
	# Build
	cmake --build build; \
	# Test
	cd build; \
	mkdir /var/tmp/mariadb; \
	ctest --output-on-failure; \
	cd ..; \
	# Install
	pkgdir="/build/mariadb-root"; \
	rootdir="$pkgdir/opt/mariadb"; \
	DESTDIR="$pkgdir" cmake --install build; \
	\
	mkdir -p "$pkgdir"/etc/my.cnf.d; \
	# Remove cruft
	rm -rfv \
		"$rootdir"/bin/mariadb_config \
		"$rootdir"/bin/mysql_config \
		"$rootdir"/include \
		"$rootdir"/share/info \
		"$rootdir"/share/man \
		"$rootdir"/share/doc \
		"$rootdir"/lib/*.a \
		"$rootdir"/lib/libmysqlclient.so \
		"$rootdir"/lib/libmysqlclient_r.so \
		"$rootdir"/lib/libmariadb.so* \
		"$rootdir"/lib/pkgconfig/libmariadb.pc \
		"$rootdir"/mysql-test \
		"$rootdir"/sql-bench \
		"$rootdir"/lib/pkgconfig


# Build and install Galera
RUN set -eux; \
	cd build; \
	cd "galera-${GALERA_VER}"; \
	# Patch
	patch -p1 < ../patches/galera-musl-page-size.patch; \
	patch -p1 < ../patches/galera-musl-sched_param.patch; \
	patch -p1 < ../patches/galera-musl-sys-poll-h.patch; \
	patch -p1 < ../patches/galera-musl-wordsize.patch; \
	patch -p1 < ../patches/galera-fix_gcomm-test-check_evs2.patch; \
	\
	patch -p1 < ../patches/galera-nk-use-std-regex-musl-bug.patch; \
	# Use MaraiDB's wsrep
	rmdir wsrep/src; \
	ln -s "../../mariadb-${MARIADB_VER}/wsrep-lib/wsrep-API/v${WSREP_VER}" wsrep/src; \
	# Compiler flags
	. /etc/buildflags; \
	\
	# Configure
	cmake -B build -G Ninja -Wno-dev \
		-DCMAKE_BUILD_TYPE=RelWithDebInfo; \
	# Build
	cmake --build build; \
	# Test
	cd build; \
	ctest --output-on-failure; \
	cd ..; \
	# Install
	pkgdir="/build/mariadb-root"; \
	rootdir="$pkgdir/opt/mariadb"; \
	mkdir -p "$rootdir/lib/galera"; \
	install -m0755 build/libgalera_smm.so "$rootdir"/lib/galera/; \
	install -m0755 build/garb/garbd "$rootdir/bin"


# Strip binaries
RUN set -eux; \
	cd build/mariadb-root; \
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


FROM registry.conarx.tech/containers/alpine/edge


ARG VERSION_INFO=

LABEL org.opencontainers.image.authors   "Nigel Kukard <nkukard@conarx.tech>"
LABEL org.opencontainers.image.version   "edge"
LABEL org.opencontainers.image.base.name "registry.conarx.tech/containers/alpine/edge"

# Set path for MariaDB
ENV PATH=/usr/local/sbin:/usr/local/bin:/opt/mariadb/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Copy in built binaries
COPY --from=builder /build/mariadb-root /


RUN set -eux; \
	true "Install requirements"; \
# NK: These are critical for some tools to work correctly
	apk add --no-cache coreutils iproute2-ss rsync socat procps pv pwgen; \
	apk add --no-cache \
		libaio libssl3 libcrypto3 pcre2 snappy zstd-libs libxml2 nghttp2-libs ncurses-libs lzo xz-libs lz4-libs libcurl \
		libbz2 brotli-libs fmt \
		; \
	true "Setup user and group"; \
	addgroup -S mysql 2>/dev/null; \
	adduser -S -D -h /var/lib/mysql -s /sbin/nologin -G mysql -g mysql mysql 2>/dev/null; \
	true "Create initdb dirs"; \
	mkdir /var/lib/mysql-initdb.d; \
	true "Install ld-musl-x86_64 path"; \
	echo "# MariaDB" >> /etc/ld-musl-x86_64.path; \
	echo "/opt/mariadb/lib" >> /etc/ld-musl-x86_64.path; \
	true "Cleanup"; \
	rm -f /var/cache/apk/*


# MariaDB
COPY etc/my.cnf /etc
COPY etc/my.cnf.d/10_fdc_defaults.cnf /etc/my.cnf.d
COPY etc/supervisor/conf.d/mariadb.conf /etc/supervisor/conf.d
COPY opt/mariadb/bin/start-mariadb /opt/mariadb/bin
COPY usr/local/share/flexible-docker-containers/init.d/42-mariadb.sh /usr/local/share/flexible-docker-containers/init.d
COPY usr/local/share/flexible-docker-containers/pre-init-tests.d/42-mariadb.sh /usr/local/share/flexible-docker-containers/pre-init-tests.d
COPY usr/local/share/flexible-docker-containers/healthcheck.d/42-mariadb.sh /usr/local/share/flexible-docker-containers/healthcheck.d
COPY usr/local/share/flexible-docker-containers/tests.d/42-mariadb.sh /usr/local/share/flexible-docker-containers/tests.d
COPY usr/local/share/flexible-docker-containers/tests.d/43-mariadb-cluster.sh /usr/local/share/flexible-docker-containers/tests.d
COPY usr/local/share/flexible-docker-containers/tests.d/99-mariadb-cluster.sh /usr/local/share/flexible-docker-containers/tests.d
RUN set -eux; \
	true "Flexible Docker Containers"; \
	if [ -n "$VERSION_INFO" ]; then echo "$VERSION_INFO" >> /.VERSION_INFO; fi; \
	chown root:root \
		/etc/my.cnf \
		/etc/my.cnf.d/10_fdc_defaults.cnf \
		/var/lib/mysql-initdb.d \
		/opt/mariadb/bin/start-mariadb; \
	chmod 0644 \
		/etc/my.cnf \
		/etc/my.cnf.d/10_fdc_defaults.cnf; \
	chmod 0755 \
		/opt/mariadb/bin/start-mariadb; \
	chmod 750 \
		/var/lib/mysql-initdb.d; \
	fdc set-perms



VOLUME ["/var/lib/mysql"]

EXPOSE 3306
