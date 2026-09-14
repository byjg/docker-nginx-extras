# The Alpine branch must match the nginx.org package branch that ships a
# prebuilt ngx_otel_module for exactly NGINX_VERSION: nginx refuses to load a
# dynamic module built against a different version, and --with-compat does not
# exempt that check.
FROM alpine:3.24

WORKDIR /var/www/html

ENV NGINX_VERSION=1.30.4
ENV MORE_SET_HEADER_VERSION=0.34
ENV FANCYINDEX=0.5.2
# Architecture is appended at build time; do not hardcode it here.
ENV MODULE_URL_BASE=https://nginx.org/packages/alpine/v3.24/main/


RUN mkdir -p /var/www/html \
    && GPG_KEYS=43387825DDB1BB97EC36BA5D007C8D7C15D87369 \
    && GPG_KEY_URL=https://nginx.org/keys/arut.key \
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
    && apk add --no-cache --virtual .build-deps \
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
    && curl -sfSL https://github.com/openresty/headers-more-nginx-module/archive/v$MORE_SET_HEADER_VERSION.tar.gz -o $MORE_SET_HEADER_VERSION.tar.gz \
    && tar xvf $MORE_SET_HEADER_VERSION.tar.gz \
    && curl -sfSL https://github.com/aperezdc/ngx-fancyindex/releases/download/v$FANCYINDEX/ngx-fancyindex-$FANCYINDEX.tar.xz -o fancyindex.tar.xz \
    && tar xvf fancyindex.tar.xz \
    && curl -sfSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
    && curl -sfSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
    && export GNUPGHOME="$(mktemp -d)" \
    # Fetch the release signing key over HTTPS from nginx.org (the sks-keyservers
    # pools are long dead), then refuse to continue unless the key we actually
    # got is the pinned fingerprint.
    && if ! curl -sfSL "$GPG_KEY_URL" -o "$GNUPGHOME/nginx.key"; then \
        echo "Falling back to hkps://keys.openpgp.org for $GPG_KEYS"; \
        gpg --batch --keyserver hkps://keys.openpgp.org --keyserver-options timeout=10 --recv-keys "$GPG_KEYS"; \
        gpg --batch --export --armor "$GPG_KEYS" > "$GNUPGHOME/nginx.key"; \
    fi \
    && { gpg --batch --show-keys --with-colons "$GNUPGHOME/nginx.key" \
            | awk -F: '/^fpr:/ { print $10 }' \
            | grep -qx "$GPG_KEYS" \
        || { echo >&2 "error: key fetched from $GPG_KEY_URL does not contain the pinned fingerprint $GPG_KEYS"; exit 1; }; } \
    && gpg --batch --import "$GNUPGHOME/nginx.key" \
    && gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
    && { pkill -9 gpg-agent || :; } \
    && { pkill -9 dirmngr || :; } \
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
# Install the prebuilt OpenTelemetry module for THIS nginx version and THIS
# architecture. The package is unpacked in a throwaway directory so nothing
# leaks into /var/www/html, which the image serves over HTTP.
RUN set -eu; \
    arch="$(apk --print-arch)"; \
    module_url="${MODULE_URL_BASE}${arch}/"; \
    package="$(wget -qO- "$module_url" \
        | grep -o "nginx-module-otel-${NGINX_VERSION}\.[0-9.]*-r[0-9]*\.apk" \
        | sort -Vr \
        | head -n 1)"; \
    if [ -z "$package" ]; then \
        echo >&2 "error: no nginx-module-otel package for nginx ${NGINX_VERSION} on ${arch} at ${module_url}"; \
        echo >&2 "       nginx will not load a module built for a different version."; \
        exit 1; \
    fi; \
    echo "Installing $package for $arch"; \
    tmp="$(mktemp -d)"; \
    wget -q -O "$tmp/otel.apk" "${module_url}${package}"; \
    # An .apk is concatenated gzip streams; busybox tar extracts the payload and
    # then complains about the trailing signature, so check the result instead.
    tar -xzf "$tmp/otel.apk" -C "$tmp" 2>/dev/null || :; \
    if [ ! -f "$tmp/usr/lib/nginx/modules/ngx_otel_module.so" ]; then \
        echo >&2 "error: ngx_otel_module.so not found inside $package"; \
        exit 1; \
    fi; \
    install -m755 "$tmp/usr/lib/nginx/modules/ngx_otel_module.so" /etc/nginx/modules/ngx_otel_module.so; \
    # The module links against gRPC/protobuf/abseil. Install exactly the shared
    # libraries the package declares (skipping its dependency on the packaged
    # nginx, since we compiled our own) - without them dlopen() fails.
    otel_deps="$(sed -n 's/^depend = \(so:.*\)$/\1/p' "$tmp/.PKGINFO")"; \
    if [ -z "$otel_deps" ]; then \
        echo >&2 "error: could not read shared library dependencies from $package"; \
        exit 1; \
    fi; \
    apk add --no-cache $otel_deps; \
    rm -rf "$tmp"

# Prove, at build time and on every architecture, that the module actually
# loads into the nginx we just compiled and that the web root is clean.
RUN set -eu; \
    printf 'load_module /etc/nginx/modules/ngx_otel_module.so;\nevents {}\nhttp {}\n' > /tmp/otel-check.conf; \
    nginx -t -c /tmp/otel-check.conf; \
    rm -f /tmp/otel-check.conf; \
    nginx -t; \
    unexpected="$(find /var/www/html -mindepth 1 -maxdepth 1 ! -name index.html ! -name 50x.html)"; \
    if [ -n "$unexpected" ]; then \
        echo >&2 "error: unexpected entries in /var/www/html:"; \
        echo >&2 "$unexpected"; \
        exit 1; \
    fi

EXPOSE 80 443
STOPSIGNAL SIGQUIT

CMD ["nginx", "-g", "daemon off;"]
