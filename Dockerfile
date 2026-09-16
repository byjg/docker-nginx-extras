FROM alpine:3.24

WORKDIR /var/www/html

ENV NGINX_VERSION=1.30.5
ENV MORE_SET_HEADER_VERSION=0.40
ENV FANCYINDEX=0.6.0
ENV MODULE_URL_BASE=https://nginx.org/packages/alpine/v3.24/main/
ENV SUBS_FILTER_COMMIT=e12e965ac1837ca709709f9a26f572a54d83430e


RUN mkdir -p /var/www/html \
    && GPG_KEYS=D6786CE303D9A9022998DC6CC8464D549AF75C0A \
    && CONFIG="\
        --prefix=/etc/nginx \
        --sbin-path=/usr/sbin/nginx \
        --modules-path=/usr/lib/nginx/modules \
        --conf-path=/etc/nginx/nginx.conf \
        --error-log-path=/var/log/nginx/error.log \
        --http-log-path=/var/log/nginx/access.log \
        --pid-path=/var/run/nginx.pid \
        --lock-path=/var/run/nginx.lock \
        --http-client-body-temp-path=/var/cache/nginx/client_temp \
        --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
        --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
        --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
        --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
        --user=nginx \
        --group=nginx \
        --with-http_ssl_module \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module \
        --with-http_dav_module \
        --with-http_flv_module \
        --with-http_mp4_module \
        --with-http_gunzip_module \
        --with-http_gzip_static_module \
        --with-http_random_index_module \
        --with-http_secure_link_module \
        --with-http_stub_status_module \
        --with-http_auth_request_module \
        --with-http_xslt_module=dynamic \
        --with-http_image_filter_module=dynamic \
        --with-http_geoip_module=dynamic \
        --with-threads \
        --with-stream \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-stream_realip_module \
        --with-stream_geoip_module=dynamic \
        --with-http_slice_module \
        --with-mail \
        --with-mail_ssl_module \
        --with-compat \
        --with-file-aio \
        --with-http_v2_module \
        --add-module=/tmp/headers-more-nginx-module-$MORE_SET_HEADER_VERSION \
        --add-module=/tmp/ngx-fancyindex-$FANCYINDEX \
        --add-module=/tmp/ngx_http_substitutions_filter_module \
    " \
    && addgroup -S nginx \
    && adduser -D -S -h /var/cache/nginx -s /sbin/nologin -G nginx nginx \
    && apk add --no-cache --allow-untrusted --virtual .build-deps \
        git \
        gcc \
        libc-dev \
        make \
        openssl-dev \
        pcre-dev \
        zlib-dev \
        linux-headers \
        curl \
        gnupg \
        libxslt-dev \
        gd-dev \
        geoip-dev \
    && cd /tmp/ \
    && git clone https://github.com/yaoweibin/ngx_http_substitutions_filter_module.git /tmp/ngx_http_substitutions_filter_module \
    && git -C /tmp/ngx_http_substitutions_filter_module checkout -q $SUBS_FILTER_COMMIT \
    && curl -sfSL https://github.com/openresty/headers-more-nginx-module/archive/v$MORE_SET_HEADER_VERSION.tar.gz -o $MORE_SET_HEADER_VERSION.tar.gz \
    && tar xvf $MORE_SET_HEADER_VERSION.tar.gz \
    && curl -sfSL https://github.com/aperezdc/ngx-fancyindex/releases/download/v$FANCYINDEX/ngx-fancyindex-$FANCYINDEX.tar.xz -o fancyindex.tar.xz \
    && tar xvf fancyindex.tar.xz \
    && curl -sfSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
    && curl -sfSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
    && export GNUPGHOME="$(mktemp -d)" \
    && found=''; \
    for server in \
        ha.pool.sks-keyservers.net \
        hkp://keyserver.ubuntu.com:80 \
        hkp://p80.pool.sks-keyservers.net:80 \
        pgp.mit.edu \
    ; do \
        echo "Fetching GPG key $GPG_KEYS from $server"; \
        gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
    gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
    && pkill -9 gpg-agent \
    && pkill -9 dirmngr \
    && rm -r "$GNUPGHOME" nginx.tar.gz.asc \
    && mkdir -p /usr/src \
    && tar -zxC /usr/src -f nginx.tar.gz \
    && rm nginx.tar.gz \
    && cd /usr/src/nginx-$NGINX_VERSION \
    && ./configure $CONFIG --with-debug \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && mv objs/nginx objs/nginx-debug \
    && mv objs/ngx_http_xslt_filter_module.so objs/ngx_http_xslt_filter_module-debug.so \
    && mv objs/ngx_http_image_filter_module.so objs/ngx_http_image_filter_module-debug.so \
    && mv objs/ngx_http_geoip_module.so objs/ngx_http_geoip_module-debug.so \
    && mv objs/ngx_stream_geoip_module.so objs/ngx_stream_geoip_module-debug.so \
    && ./configure $CONFIG \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && make install \
    && rm -rf /etc/nginx/html/ \
    && mkdir /etc/nginx/conf.d/ \
    && mkdir -p /usr/share/nginx/html/ \
    && install -m644 html/index.html /usr/share/nginx/html/ \
    && install -m644 html/50x.html /usr/share/nginx/html/ \
    && install -m755 objs/nginx-debug /usr/sbin/nginx-debug \
    && install -m755 objs/ngx_http_xslt_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_xslt_filter_module-debug.so \
    && install -m755 objs/ngx_http_image_filter_module-debug.so /usr/lib/nginx/modules/ngx_http_image_filter_module-debug.so \
    && install -m755 objs/ngx_http_geoip_module-debug.so /usr/lib/nginx/modules/ngx_http_geoip_module-debug.so \
    && install -m755 objs/ngx_stream_geoip_module-debug.so /usr/lib/nginx/modules/ngx_stream_geoip_module-debug.so \
    && ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
    && strip /usr/sbin/nginx* \
    && strip /usr/lib/nginx/modules/*.so \
    && rm -rf /usr/src/nginx-$NGINX_VERSION \
    \
    # Bring in gettext so we can get `envsubst`, then throw
    # the rest away. To do this, we need to install `gettext`
    # then move `envsubst` out of the way so `gettext` can
    # be deleted completely, then move `envsubst` back.
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    \
    && runDeps="$( \
        scanelf --needed --nobanner /usr/sbin/nginx /usr/lib/nginx/modules/*.so /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache --virtual .nginx-rundeps $runDeps apache2-utils \
    c-ares \
    libstdc++ \
    curl \
    && apk del --no-cache .build-deps \
    && apk del --no-cache .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
    && rm /tmp/$MORE_SET_HEADER_VERSION.tar.gz \
    && rm -rf /tmp/headers-more-nginx-module-$MORE_SET_HEADER_VERSION \
    && rm /tmp/fancyindex.tar.xz \
    && rm -rf /tmp/ngx-fancyindex-$FANCYINDEX \
    && rm -rf /tmp/ngx_http_substitutions_filter_module \
    && rm -rf /tmp/pear \
    \
    # forward request and error logs to docker log collector
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log \
    && cp /usr/share/nginx/html/* /var/www/html

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/nginx.vh.default.conf /etc/nginx/conf.d/default.conf

# ngx_otel_module ships as a *prebuilt* binary. nginx refuses to load a dynamic
# module whose version differs from its own (src/core/ngx_module.c, which
# --with-compat does not exempt), so pin the apk to NGINX_VERSION rather than
# grabbing the newest one, and fail the build if no matching apk exists.
#
# It also has runtime dependencies of its own that this image does not
# otherwise carry (otel 0.1.2+ links grpc/protobuf/abseil, 0.1.0 did not), so
# resolve whatever the apk itself declares instead of hardcoding a list.
# nginx -t at the end proves the module actually loads.
RUN set -eux; \
    apkarch="$(apk --print-arch)"; \
    index="${MODULE_URL_BASE}${apkarch}/"; \
    escaped="$(echo "$NGINX_VERSION" | sed 's/\./\\./g')"; \
    otel_apk="$(wget -qO- "$index" \
        | grep -oE "nginx-module-otel-${escaped}\.[0-9.]+-r[0-9]+\.apk" \
        | sort -Vr | head -n 1)"; \
    if [ -z "$otel_apk" ]; then \
        echo "ERROR: no nginx-module-otel build for nginx ${NGINX_VERSION} on ${apkarch}." >&2; \
        echo "       Check ${index} and pick a version that exists there." >&2; \
        exit 1; \
    fi; \
    tmp="$(mktemp -d)"; \
    wget -qO "$tmp/otel.apk" "${index}${otel_apk}"; \
    tar -xzf "$tmp/otel.apk" -C "$tmp"; \
    apk add --no-cache --virtual .otel-rundeps \
        $(grep '^depend = so:' "$tmp/.PKGINFO" | sed 's/^depend = //'); \
    install -m755 "$tmp/usr/lib/nginx/modules/ngx_otel_module.so" \
                  /etc/nginx/modules/ngx_otel_module.so; \
    rm -rf "$tmp"; \
    printf 'load_module modules/ngx_otel_module.so;\nevents {}\nhttp {}\n' > /tmp/otel-check.conf; \
    nginx -t -c /tmp/otel-check.conf; \
    rm /tmp/otel-check.conf

EXPOSE 80 443
STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]
