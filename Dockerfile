FROM alpine:latest
LABEL maintainer="developer@ucconnect.co.th"

LABEL name=nfs-server
LABEL version=1.0.0
LABEL author=jgrewal@po1.me
LABEL source "https://github.com/iamgrewal/docker-nfs-server"
LABEL branch "master"

USER 0

ARG DOCKER_UID=1000
ARG DOCKER_GID=1000
ARG SRC_PATH_PREFIX=""
#"/alpine/"
ARG NFS_GANESHA_VERSION="6.3"
ARG NFS_GANESHA_BUILD="1"
ARG EXTRA_CMAKE_ARGS=""

# Install prerequisite tools {
RUN echo "## Installing prerequisites {"; \
    set -ex; \
    apk update; \
    apk add --no-cache \
    wget tar bzip2 xz perl openssl libressl gnupg tree \
    ca-certificates coreutils dpkg tzdata \
    libedit libxml2 pcre bison flex; \
    buildDeps=' \
        git g++ gcc build-base cmake make binutils-gold doxygen \
        libgcc linux-headers libexecinfo-dev libnfs-dev \
        openssl-dev krb5-dev libgssglue-dev flex-dev portablexdr-dev \
        #libtirpc-dev \
    '; \
    export buildDeps; \
    echo ${buildDeps}; \
    apk add --no-cache --virtual .build-tools ${buildDeps}; \
    set +ex; \
    echo "## }"
# }

# Ensure docker user {

RUN echo "## Checking docker user ID {"; \
    set -x; \
    addgroup -g "${DOCKER_GID}" docker && \
    adduser -u "${DOCKER_UID}" -G docker -s /bin/sh -D docker; \
    echo '%docker ALL=(ALL) NOPASSWD:ALL' >>/etc/sudoers; \
    id docker; \
    set +x; \
    echo "## }"
# }
    
# Download&Install NFS Ganesha {

WORKDIR /usr/src
RUN echo "## Downloading&Installing NFS Ganesha v${NFS_GANESHA_VERSION} {"; \
    set -ex; \
    git clone --recursive --single-branch --branch "V${NFS_GANESHA_VERSION}-stable" git://github.com/nfs-ganesha/nfs-ganesha.git "nfs-ganesha-${NFS_GANESHA_VERSION}"; \
    #wget "https://download.nfs-ganesha.org/${NFS_GANESHA_VERSION}/${NFS_GANESHA_VERSION}.${NFS_GANESHA_BUILD}/nfs-ganesha-${NFS_GANESHA_VERSION}.${NFS_GANESHA_BUILD}.tar.gz"; \
    #tar xzvf "nfs-ganesha-${NFS_GANESHA_VERSION}.${NFS_GANESHA_BUILD}.tar.gz"; \
    cd "nfs-ganesha-${NFS_GANESHA_VERSION}/"; \
    #git fetch && git checkout "V${NFS_GANESHA_VERSION}-stable" && git pull; \
    git submodule update --init --recursive; \
    #chmod +x ./configure; \
    #./configure; \
    mkdir -p build; \
    cd build/; \
    cmake -DCMAKE_BUILD_TYPE=Release -DUSE_FSAL_ZFS=OFF -DUSE_FSAL_CEPHFS=OFF ${EXTRA_CMAKE_ARGS} ../src; \
    #lsb_release -a; \
    cat /etc/os-release; \
    make; \
    make install; \
    set +ex; \
    echo "## }"

# }


# Check&reconfigure NFS Server {

#TEST {
RUN echo "## /etc/exports: {"; \
    set -x; \
    cat /etc/exports; \
    set +x; \
    echo "## }"
# }

COPY "${SRC_PATH_PREFIX}docker-entrypoint.sh" "/usr/local/bin/"

ENV NFS_DIR="/home/docker/nfs-shared"
ENV NFS_PORT="2049"
ENV NFS_ALLOWED_HOSTS "${NFS_ALLOWED_HOSTS:*"

RUN echo "## Checking&Configuring NFSD {"; \
    set -x; \
    echo "${NFS_DIR} ${NFS_ALLOWED_HOSTS}(rw,sync)" >>/etc/exports; \
    mkdir -p "${NFS_DIR}"; \
    chown -R docker:docker "${NFS_DIR}"; \
    chmod -R 777 "${NFS_DIR}"; \
    chown root:docker "/usr/local/bin/docker-entrypoint.sh"; \
    chmod ug+x "/usr/local/bin/docker-entrypoint.sh"; \
    chown root:docker "/usr/bin/ganesha.nfsd"; \
    chmod ug+x "/usr/bin/ganesha.nfsd"; \
    set +x; \
    echo "## }"
    
#TEST {
RUN echo "## NFSD Config files {"; \
    echo "### /etc/exports: {"; \
    cat /etc/exports; \
    echo "### }"; \
    echo "## }"
# }

RUN echo "## Cleaning up {"; \
    set -x; \
    echo ${buildDeps}; \
    apk del .build-tools; \
    set +x; \
    echo "## }"
    
# Install additional tools {
# traceroute for Alpine is in package: iputils
RUN echo "## Installing extra tools {"; \
    set -x; \
    apk add --no-cache \
    nano vim net-tools iputils; \
    set +x; \
    echo "## }"
    
# }

WORKDIR ${NFS_DIR}

VOLUME ${NFS_DIR}

EXPOSE 111 111/udp 662 ${NFS_PORT} 38465-38467

USER ${DOCKER_UID}

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/bin/sh", "-c"]