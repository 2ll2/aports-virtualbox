FROM 2ll2/repo-virtualbox:v3.7-dcfd779-x86_64 AS repo-virtualbox

FROM alpine:3.7

COPY [ \
  "./docker-extras/*", \
  "/tmp/docker-build/" \
]

RUN \
  # apk
  apk update && \
  \
  apk add \
    abuild \
    alpine-baselayout \
    alpine-conf \
    gcc \
    mkinitfs \
    squashfs-tools \
    sudo \
    vim \
    xorriso && \
  \
  mkdir -p /var/cache/distfiles && \
  adduser -D -u 500 builder && \
  addgroup builder abuild && \
  chgrp abuild /var/cache/distfiles && \
  chmod g+w /var/cache/distfiles && \
  echo "builder    ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers && \
  su -l builder -c "mkdir .abuild" && \
  su -l builder -c "cp /tmp/docker-build/home-builder-.abuild-Builder-59ffc9b9.rsa.pub .abuild/Builder-59ffc9b9.rsa.pub" && \
  cp /home/builder/.abuild/*.rsa.pub /etc/apk/keys && \
  \
  # Apply patches to /usr/share/mkinitfs/initramfs-init and /sbin/update-kernel
  cd /usr/share/mkinitfs && \
  patch -p1 < /tmp/docker-build/initramfs-init-add-2ll2.patch && \
  cd /sbin && \
  patch -p1 < /tmp/docker-build/update-kernel-add-2ll2.patch && \
  \
  # cleanup
  cd /root && \
  rm -rf /tmp/* && \
  rm -f /var/cache/apk/*

COPY --from=repo-virtualbox /home/builder/repo/virtualbox/ /home/builder/repo/virtualbox/
