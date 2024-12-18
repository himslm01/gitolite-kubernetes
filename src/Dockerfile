FROM alpine:3.21.0

RUN apk add --update --no-cache \
        git \
        openssh-server \
        perl \
        tini \
 && rm -rf /tmp/*

WORKDIR /opt
ADD https://github.com/tianon/gosu/releases/download/1.17/gosu-amd64 /usr/local/bin/gosu
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod 0755 /usr/local/bin/gosu /opt/entrypoint.sh \
 && git clone https://github.com/sitaramc/gitolite.git \
 && cd gitolite \
 && git checkout v3.6.13 \
 && /opt/gitolite/install -ln /usr/local/bin/

ENV USER=git
ENV HOME=/home/${USER}
WORKDIR ${HOME}

VOLUME ${HOME}
VOLUME /sshd
VOLUME /repositories
EXPOSE 2222
ENTRYPOINT ["tini", "--", "/opt/entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D", "-e", "-f", "/sshd/sshd_config"]

LABEL org.opencontainers.image.source=https://github.com/himslm01/gitolite-kubernetes
LABEL org.opencontainers.image.description="Gitolite"
LABEL org.opencontainers.image.licenses=MIT
