FROM alpine:3.5

MAINTAINER Chris Aubuchon <Chris.Aubuchon@gmail.com>


ADD https://releases.hashicorp.com/consul-template/0.18.1/consul-template_0.18.1_linux_amd64.zip /

RUN unzip consul-template_0.18.1_linux_amd64.zip && \
    mv consul-template /usr/local/bin/consul-template &&\
    rm -rf /consul-template_0.18.1_linux_amd64.zip

ENV HAPROXY_MAJOR 1.7
ENV HAPROXY_VERSION 1.7.2
ENV HAPROXY_MD5 7330b36f3764ebe409e9305803dc30e2

# https://www.lua.org/ftp/#source
ENV LUA_VERSION=5.3.3 \
	LUA_SHA1=a0341bc3d1415b814cc738b2ec01ae56045d64ef

# see http://sources.debian.net/src/haproxy/jessie/debian/rules/ for some helpful navigation of the possible "make" arguments

RUN apk add --update bash

RUN set -x \
	\
	&& apk add --no-cache --virtual .build-deps \
		ca-certificates \
		gcc \
		libc-dev \
		linux-headers \
		make \
		openssl \
		openssl-dev \
		pcre-dev \
		readline-dev \
		tar \
		zlib-dev \
	\
# install Lua
	&& wget -O lua.tar.gz "https://www.lua.org/ftp/lua-$LUA_VERSION.tar.gz" \
	&& echo "$LUA_SHA1 *lua.tar.gz" | sha1sum -c \
	&& mkdir -p /usr/src/lua \
	&& tar -xzf lua.tar.gz -C /usr/src/lua --strip-components=1 \
	&& rm lua.tar.gz \
	&& make -C /usr/src/lua -j "$(getconf _NPROCESSORS_ONLN)" linux \
	&& make -C /usr/src/lua install \
# put things we don't care about into a "trash" directory for purging
		INSTALL_BIN='/usr/src/lua/trash/bin' \
		INSTALL_CMOD='/usr/src/lua/trash/cmod' \
		INSTALL_LMOD='/usr/src/lua/trash/lmod' \
		INSTALL_MAN='/usr/src/lua/trash/man' \
# ... and since it builds static by default, put those bits somewhere we can purge after we build haproxy
		INSTALL_INC='/usr/local/lua-install/inc' \
		INSTALL_LIB='/usr/local/lua-install/lib' \
	&& rm -rf /usr/src/lua \
	\
# install HAProxy
	&& wget -O haproxy.tar.gz "http://www.haproxy.org/download/${HAPROXY_MAJOR}/src/haproxy-${HAPROXY_VERSION}.tar.gz" \
	&& echo "$HAPROXY_MD5 *haproxy.tar.gz" | md5sum -c \
	&& mkdir -p /usr/src/haproxy \
	&& tar -xzf haproxy.tar.gz -C /usr/src/haproxy --strip-components=1 \
	&& rm haproxy.tar.gz \
	\
	&& makeOpts=' \
		TARGET=linux2628 \
		USE_LUA=1 LUA_INC=/usr/local/lua-install/inc LUA_LIB=/usr/local/lua-install/lib \
		USE_OPENSSL=1 \
		USE_PCRE=1 PCREDIR= \
		USE_ZLIB=1 \
	' \
	&& make -C /usr/src/haproxy -j "$(getconf _NPROCESSORS_ONLN)" all $makeOpts \
	&& make -C /usr/src/haproxy install-bin $makeOpts \
	\
# purge the remnants of our static Lua
	&& rm -rf /usr/local/lua-install \
	\
	&& mkdir -p /usr/local/etc/haproxy \
	&& cp -R /usr/src/haproxy/examples/errorfiles /usr/local/etc/haproxy/errors \
	&& rm -rf /usr/src/haproxy \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner --recursive /usr/local \
			| awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
			| sort -u \
			| xargs -r apk info --installed \
			| sort -u \
	)" \
	&& apk add --virtual .haproxy-rundeps $runDeps \
	&& apk del .build-deps


ADD config/haproxy/startup.sh /startup.sh
ADD config/haproxy/haproxy.sh /haproxy.sh
RUN chmod u+x /startup.sh
RUN chmod u+x /haproxy.sh
RUN mkdir /etc/haproxy
RUN adduser -S haproxy
RUN chown haproxy /etc/haproxy
RUN chmod 777 /etc/haproxy
RUN chown haproxy /*.sh
RUN chmod 777 /var/run

EXPOSE 8080

USER haproxy

WORKDIR /

CMD [ "/startup.sh"]