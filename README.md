# Nginx extras (all modules)

[![Opensource ByJG](https://img.shields.io/badge/opensource-byjg-success.svg)](http://opensource.byjg.com)
[![Build Status](https://github.com/byjg/docker-nginx-extras/actions/workflows/build.yml/badge.svg?branch=master)](https://github.com/byjg/docker-nginx-extras/actions/workflows/build.yml)
[![GitHub source](https://img.shields.io/badge/Github-source-informational?logo=github)](https://github.com/byjg/docker-nginx-extras/)
[![GitHub license](https://img.shields.io/github/license/byjg/docker-nginx-extras.svg)](https://opensource.byjg.com/license/)
[![GitHub release](https://img.shields.io/github/release/byjg/docker-nginx-extras.svg)](https://github.com/byjg/docker-nginx-extras/releases/)

Nginx extended version: provides a version of nginx with the standard modules, plus extra features and modules,
this container is based on Alpine Linux and the nginx is compiled from the source code.

## Tags

| Tag | Published when |
|-----|----------------|
| `latest` | every push to `master` |
| `1.30` | every push to `master` — the `<major>.<minor>` of `NGINX_VERSION` in the Dockerfile |
| `1.2.3` | a full semver git tag is pushed (`git tag 1.2.3 && git push --tags`) |

The image currently ships nginx **1.30.4** on Alpine **3.24**, for `linux/amd64`
and `linux/arm64`.

Older `1.10` ... `1.26` tags are still on Docker Hub from previous releases, but
they are not rebuilt.

## STANDARD HTTP MODULES

Core, Access, Auth Basic, Auto Index, Browser,
Charset, Empty GIF, FastCGI, Geo, Gzip, Headers, Index, Limit Requests,
Limit Zone, Log, Map, Memcached, Proxy, Referer, Rewrite, SCGI,
Split Clients, SSI, Upstream, User ID, UWSGI.

## OPTIONAL HTTP MODULES

Addition, Debug, Embedded Perl, FLV, GeoIP, Open Telemetry (Otel),
Gzip Precompression, Image Filter, IPv6, MP4, Random Index, Real IP,
Secure Link, Spdy, SSL, Stub Status, Substitution, WebDAV, XSLT.

## MAIL MODULES

Mail Core, IMAP, POP3, SMTP, SSL.

## THIRD PARTY MODULES

Auth PAM, Chunkin, DAV Ext, Echo, Embedded Lua,
Fancyindex, HttpHeadersMore, HTTP Substitution Filter, http push,
Nginx Development Kit, Upload Progress, Upstream Fair Queue.

## Usage

### Important volume mappings

* /var/www/html - Root folder
* /etc/nginx/conf.d/ - configuration folder

```bash
docker run  -v /path/to/html:/var/www/html -p 8080:80 byjg/nginx-extras
```

If you want to setup your own configuration run:

```bash
docker run  -v /path/to/html:/var/www/html -v /path/to/sites-enabled:/etc/nginx/conf.d -p 8080:80 byjg/nginx-extras
```

## Note

This Dockerfile uses code from :

* [https://github.com/x-drum/docker-nginx-extras](https://github.com/x-drum/docker-nginx-extras) and
* [https://github.com/yfix/docker-nginx](https://github.com/x-drum/docker-nginx-extras) (fork from the first)

I removed a lot of things and simplify some code.

----
[Open source ByJG](http://opensource.byjg.com)
