FROM quay.io/sclorg/nginx-122-micro-c9s:20240214 AS upstream
FROM ghcr.io/radiorabe/ubi9-minimal:0.6.4 AS build

ENV APP_ROOT=/opt/app-root

ENV NGINX_VERSION=1.22

RUN    mkdir -p /mnt/rootfs \
    && microdnf module enable nginx:$NGINX_VERSION -y \
       --releasever 9 \
       --installroot /mnt/rootfs \
       --noplugins \
       --config /etc/dnf/dnf.conf \
       --setopt install_weak_deps=0 --nodocs \
       --setopt cachedir=/var/cache/dnf \
       --setopt reposdir=/etc/yum.repos.d \
       --setopt varsdir=/etc/yum.repos.d \
    && microdnf -y module enable nginx:$NGINX_VERSION \
    && microdnf install -y \
       --releasever 9 \
       --installroot /mnt/rootfs \
       --noplugins \
       --config /etc/dnf/dnf.conf \
       --setopt install_weak_deps=0 --nodocs \
       --setopt cachedir=/var/cache/dnf \
       --setopt reposdir=/etc/yum.repos.d \
       --setopt varsdir=/etc/yum.repos.d \
         bind-utils \
         findutils \
         gettext \
         hostname \
         nginx-core \
         nss_wrapper-libs \
    && cp \
       /etc/pki/ca-trust/source/anchors/rabe-ca.crt \
       /mnt/rootfs/etc/pki/ca-trust/source/anchors/ \
    && update-ca-trust \
    && chmod a-s \
       /mnt/rootfs/usr/bin/* \
       /mnt/rootfs/usr/sbin/* \
       /mnt/rootfs/usr/libexec/*/* \
    && rm -rf \
       /mnt/rootfs/var/cache/* \
       /mnt/rootfs/var/log/dnf* \
       /mnt/rootfs/var/log/yum.*

FROM scratch as app

ENV NGINX_VERSION=1.22 \
    NGINX_CONF_PATH=/etc/nginx/nginx.conf \
    NGINX_CONTAINER_SCRIPTS_PATH=/usr/share/container-scripts/nginx \
    NGINX_LOG_PATH=/var/log/nginx \
    STI_SCRIPTS_PATH=/usr/libexec/s2i \
    APP_ROOT=/opt/app-root \
    SUMMARY="Nginx Image for RaBe" \
    PLATFORM=el9

ENV NGINX_CONFIGURATION_PATH=${APP_ROOT}/etc/nginx.d \
    NGINX_DEFAULT_CONF_PATH=${APP_ROOT}/etc/nginx.default.d \
    NGINX_APP_ROOT=${APP_ROOT} \
    STI_SCRIPTS_URL=image://${STI_SCRIPTS_PATH}

COPY --from=build /mnt/rootfs/ /
COPY --from=upstream ${STI_SCRIPTS_PATH} ${STI_SCRIPTS_PATH}
COPY --from=upstream ${NGINX_CONTAINER_SCRIPTS_PATH} ${NGINX_CONTAINER_SCRIPTS_PATH}
COPY --from=upstream ${APP_ROOT} ${APP_ROOT}

RUN    sed -i -f ${NGINX_APP_ROOT}/nginxconf.sed ${NGINX_CONF_PATH} \
    && mkdir -p \
          ${NGINX_APP_ROOT}/etc/nginx.d/ \
          ${NGINX_APP_ROOT}/etc/nginx.default.d/ \
          ${NGINX_APP_ROOT}/src/nginx-start/ \
          ${NGINX_CONTAINER_SCRIPTS_PATH}/nginx-start \
          ${NGINX_LOG_PATH} \
    && chown -R 1001:0 \
          ${NGINX_CONF_PATH} \
          ${NGINX_APP_ROOT}/etc \
          ${NGINX_APP_ROOT}/src/nginx-start/  \
          ${NGINX_CONTAINER_SCRIPTS_PATH}/nginx-start \
          /var/lib/nginx \
          /var/log/nginx \
          /run \
    && chmod ug+rw \
          ${NGINX_CONF_PATH} \
    && chmod -R ug+rwX \
          ${NGINX_APP_ROOT}/etc \
          ${NGINX_APP_ROOT}/src/nginx-start/  \
          ${NGINX_CONTAINER_SCRIPTS_PATH}/nginx-start \
          /var/lib/nginx \
          /var/log/nginx \
          /run

WORKDIR /opt/app-root/src

USER 1001

STOPSIGNAL SIGQUIT

CMD ${STI_SCRIPTS_PATH}/usage
