# SPDX-License-Identifier: MPL-2.0

# This Kea docker image provides the following functionality:
# - running Kea DHCPv4 service
# - running Kea control agent (exposes REST API over http)
# - open source hooks
# - possible to build with premium hooks

FROM alpine:3.18
LABEL org.opencontainers.image.authors="Kea Developers <kea-dev@lists.isc.org>"

# Add Kea packages from cloudsmith. Make sure the version matches that of the Alpine version.
# Also, install all the open source hooks. When updating, new instructions can
# be found at: https://cloudsmith.io/~isc/repos/kea-2-5/setup/#formats-alpine
ARG VERSION=2.5
ARG TOKEN
ARG PREMIUM

SHELL ["/bin/ash", "-o", "pipefail", "-c"]
RUN cp /etc/apk/repositories /etc/apk/repositories_backup && \
    # Install curl and bash
    apk update && apk add --no-cache curl bash && \
    # Setup Cloudsmith repo
    curl -1sLf "https://dl.cloudsmith.io/public/isc/kea-$(echo "${VERSION}" | cut -c1;)-$(echo "${VERSION}" | cut -c3;)/setup.alpine.sh" | bash && \
    apk update && \
    # Install main Kea packaegs and supervisor
    apk add --no-cache isc-kea-dhcp4~=${VERSION} isc-kea-ctrl-agent~=${VERSION} isc-kea-hooks~=${VERSION} supervisor && \
    # If token is provided add premium Cloudsmith repository
    if [ -n "$TOKEN" ]; then \
    curl -1sLf "https://dl.cloudsmith.io/${TOKEN}/isc/kea-$(echo "${VERSION}" | cut -c1;)-$(echo "${VERSION}" | cut -c3;)-prv/setup.alpine.sh" | bash && \
    apk update && \
    # Install premium Kea hooks
    apk add --no-cache \
        isc-kea-premium-ddns-tuning~=${VERSION} \
        isc-kea-premium-flex-id~=${VERSION} \
        isc-kea-premium-forensic-log~=${VERSION} \
        isc-kea-premium-host-cmds~=${VERSION}; \
    fi && \
    # Install subscription Kea hooks (provided TOKEN should have access to those pkgs)
    if [ -n "$TOKEN" ] && [ "$PREMIUM" = "SUBSCRIPTION" ]; then \
    apk add --no-cache \
        isc-kea-premium-cb-cmds~=${VERSION} \
        isc-kea-premium-class-cmds~=${VERSION} \
        isc-kea-premium-host-cache~=${VERSION} \
        isc-kea-premium-lease-query~=${VERSION} \
        isc-kea-premium-limits~=${VERSION} \
        isc-kea-premium-ping-check~=${VERSION} \
        isc-kea-premium-radius~=${VERSION} \
        isc-kea-premium-subnet-cmds~=${VERSION}; \
    fi && \
    # Install subscription and enterprise Kea hooks (provided TOKEN should have access to those pkgs)
    if [ -n "$TOKEN" ] && [ "$PREMIUM" = "ENTERPRISE" ]; then \
    apk add --no-cache \
        isc-kea-premium-cb-cmds~=${VERSION} \
        isc-kea-premium-class-cmds~=${VERSION} \
        isc-kea-premium-host-cache~=${VERSION} \
        isc-kea-premium-lease-query~=${VERSION} \
        isc-kea-premium-limits~=${VERSION} \
        isc-kea-premium-ping-check~=${VERSION} \
        isc-kea-premium-radius~=${VERSION} \
        isc-kea-premium-subnet-cmds~=${VERSION} \
        isc-kea-premium-rbac~=${VERSION}; \
    fi && \
    # Revert Cloudsmith repositories
    mv /etc/apk/repositories_backup /etc/apk/repositories && \
    # Create directory for supervisor logs
    mkdir -p /var/log/supervisor && \
    # remove curl and bash
    apk del curl bash


VOLUME ["/etc/kea", "/var/lib/kea/"]

# Copy supervisor configs
COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY supervisor-kea-dhcp4.conf /etc/supervisor/conf.d/kea-dhcp4.conf
COPY supervisor-kea-agent.conf /etc/supervisor/conf.d/kea-agent.conf

# Copy Kea configs
COPY kea-ctrl-agent.conf /etc/kea/kea-ctrl-agent.conf
COPY kea-dhcp4.conf /etc/kea/kea-dhcp4.conf

# 8000 ctrl agent
# 8001 HA MT
# 67 blq
EXPOSE 8000-8001/tcp 67/tcp 67/udp

CMD ["supervisord", "-c", "/etc/supervisor/supervisord.conf"]
HEALTHCHECK CMD [ "supervisorctl", "status" ]
