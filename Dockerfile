# The purpose of this Dockerfile is to build components which can be
# included when we create another image elsewhere.
#
# The components we build here are:
#   libmodsecurity
#   nginx module which is the "connector" to libmodsecurity
#
# Please edit the version numbers below to meet your requirements, then:
#   docker build -t modsec - < Dockerfile
#   docker run modsec
#
# This article was helpful:
#   <https://www.linuxjournal.com/content/modsecurity-and-nginx>
#
# ==========================================================================
# This Dockerfile is Copyright 2019 Quoin Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   <https://www.apache.org/licenses/LICENSE-2.0>
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# The built components are copyrighted and licensed by others,
# as may be seen in their source code repositories.
# ==========================================================================
#
ARG V_NGINX=1.16.1

# We want to build in the same environment that nginx will run in,
# so we start from the nginx base image.
FROM nginx:${V_NGINX}

# we redefine V_NGINX because FROM made us forget V_NGINX
ARG V_NGINX=${NGINX_VERSION}

ARG V_MODSEC=v3.0.3
ARG V_MODSECNGX=d7101e1368
ARG GITURLBASE=github.com/SpiderLabs
# ==========================================================================

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update

# How best to ensure the images are up to date is controversial.
# RUN apt-get -y upgrade

RUN apt-get -y install \
 wget \
 gcc g++ bison flex make automake \
 pkg-config libtool doxygen git curl \
 zlib1g-dev libxml2-dev libpcre3-dev build-essential \
 libyajl-dev yajl-tools liblmdb-dev rdmacm-utils libgeoip-dev \
 libcurl4-openssl-dev liblua5.2-dev libfuzzy-dev openssl libssl-dev

RUN useradd --home-dir /build --create-home --user-group --shell /bin/bash builder

USER builder
RUN cd /build ; wget http://nginx.org/download/nginx-${V_NGINX}.tar.gz
RUN cd /build ; tar xzf nginx-${V_NGINX}.tar.gz

# This was tried but became awkward:
# git clone --branch ${V_MODSEC} --depth 1 ...

RUN cd /build ; git clone https://${GITURLBASE}/ModSecurity.git
RUN cd /build/ModSecurity ; git checkout ${V_MODSEC} ; git submodule update --init --recursive
RUN cd /build/ModSecurity ; sh build.sh ; ./configure ; make

USER root
RUN cd /build/ModSecurity ; make install

USER builder
RUN cd /build ; git clone https://${GITURLBASE}/ModSecurity-nginx.git
RUN cd /build/ModSecurity-nginx ; git checkout ${V_MODSECNGX} ; git submodule update --init --recursive
RUN cd /build/nginx-${V_NGINX} ; ./configure --with-compat --add-dynamic-module=/build/ModSecurity-nginx ; make modules

USER root
RUN \
  rm -rf /usr/local/modsecurity/include /usr/local/modsecurity/lib/*a \
; mv /build/nginx-${V_NGINX}/objs/ngx_http_modsecurity_module.so /usr/local/modsecurity/ \
; mv /build/ModSecurity/LICENSE /usr/local/modsecurity/ \
; echo "Source code, copyright notices, and license grants are at:" > /usr/local/modsecurity/SOURCE \
; echo " https://${GITURLBASE}/ModSecurity" >> /usr/local/modsecurity/SOURCE \
; echo " https://${GITURLBASE}/ModSecurity-nginx" >> /usr/local/modsecurity/SOURCE \
; mkdir /output \
; cd /output \
; tar czvf libmodsec-${V_MODSEC}-nginx-${V_NGINX}-mod-${V_MODSECNGX}.tgz -C /usr/local modsecurity \
; ls -l /output/*

CMD ["/bin/bash", "-c", "printf '\n\n  Suggestion ---> docker cp %s:/output ./\n\n\n' $(hostname)"]
