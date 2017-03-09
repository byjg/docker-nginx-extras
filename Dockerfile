FROM ubuntu:16.04

RUN echo "deb http://ppa.launchpad.net/nginx/development/ubuntu xenial main" > /etc/apt/sources.list.d/nginx-stable.list \
  && apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C300EE8C \
  \
  && apt-get update && apt-get install -y \
    nginx-extras \
  \
  && apt-get autoremove -y \
  && apt-get clean -y \
  && rm -rf /var/lib/apt/lists/* \
  \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]

