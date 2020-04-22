FROM yriveiro/tini:1.0.0 as tini
FROM yriveiro/gosu:1.0.0 as gosu
FROM alpine:3

LABEL maintainer="yago.riveiro@gmail.com"

RUN apk add --no-cache \
    openssh==8.1_p1-r0 \
    shadow==4.7-r1 \
    openssh-sftp-server==8.1_p1-r0 \
    bash==5.0.11-r1 && \
    rm -rf /var/cache/apk/*

COPY --from=tini /sbin/tini /sbin/tini
COPY --from=gosu /usr/local/bin/gosu /usr/local/bin

WORKDIR /
COPY docker-entrypoint.sh .
COPY sshd_config /etc/ssh/sshd_config

ENTRYPOINT ["/sbin/tini", "-g", "--", "/docker-entrypoint.sh"]
CMD ["tool"]
