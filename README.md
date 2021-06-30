# Nginx extras (all modules)

[![Opensource ByJG](https://img.shields.io/badge/opensource-byjg-success.svg)](http://opensource.byjg.com)
[![GitHub source](https://img.shields.io/badge/Github-source-informational?logo=github)](https://github.com/byjg/docker-nginx-extras/)
[![GitHub license](https://img.shields.io/github/license/byjg/docker-nginx-extras.svg)](https://opensource.byjg.com/opensource/licensing.html)
[![GitHub release](https://img.shields.io/github/release/byjg/docker-nginx-extras.svg)](https://github.com/byjg/docker-nginx-extras/releases/)

Nginx extended version: provides a version of nginx with the standard modules, plus extra features and modules,
this container is based on Alpine Linux and the nginx is compiled from the source code.

## Tags:
* 1.20, latest
* 1.19
* 1.18
* 1.17 
* 1.16
* 1.15
* 1.14
* 1.13
* 1.12
* 1.11
* 1.10

## STANDARD HTTP MODULES: 
Core, Access, Auth Basic, Auto Index, Browser,
Charset, Empty GIF, FastCGI, Geo, Gzip, Headers, Index, Limit Requests,
Limit Zone, Log, Map, Memcached, Proxy, Referer, Rewrite, SCGI,
Split Clients, SSI, Upstream, User ID, UWSGI.

## OPTIONAL HTTP MODULES:
Addition, Debug, Embedded Perl, FLV, GeoIP,
Gzip Precompression, Image Filter, IPv6, MP4, Random Index, Real IP,
Secure Link, Spdy, SSL, Stub Status, Substitution, WebDAV, XSLT.

## MAIL MODULES:
Mail Core, IMAP, POP3, SMTP, SSL.

## THIRD PARTY MODULES:
Auth PAM, Chunkin, DAV Ext, Echo, Embedded Lua,
Fancy Index, HttpHeadersMore, HTTP Substitution Filter, http push,
Nginx Development Kit, Upload Progress, Upstream Fair Queue.

## Usage

```bash
$ docker run  -v /path/to/html:/var/www/html -p 8080:80 byjg/nginx-extras
```

If you want to setup your own configuration run:

```bash
$ docker run  -v /path/to/html:/var/www/html -v /path/to/sites-enabled:/etc/nginx/sites-enabled -p 8080:80 byjg/nginx-extras
```

## Note

This Dockerfile uses code from :
* https://github.com/x-drum/docker-nginx-extras and
* https://github.com/yfix/docker-nginx (fork from the first)

I removed a lot of things and simplify some code.

----
[Open source ByJG](http://opensource.byjg.com)
