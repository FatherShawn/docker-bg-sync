FROM alpine:3.5

# Install needed packages.
#RUN apt-get -qq update && \
#    apt-get -qq install inotify-tools rsync unison-all && \
#    apt-get clean && \
#    rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

# Alpine doesn't ship with Bash.
RUN apk add --no-cache bash

# Install Unison from source with inotify support + remove compilation tools
ARG UNISON_VERSION=2.48.4
RUN apk add --no-cache --virtual .build-dependencies build-base curl && \
    apk add --no-cache inotify-tools && \
    apk add --no-cache --repository http://dl-4.alpinelinux.org/alpine/edge/testing/ ocaml && \
    curl -L https://github.com/bcpierce00/unison/archive/$UNISON_VERSION.tar.gz | tar zxv -C /tmp && \
    cd /tmp/unison-${UNISON_VERSION} && \
    sed -i -e 's/GLIBC_SUPPORT_INOTIFY 0/GLIBC_SUPPORT_INOTIFY 1/' src/fsmonitor/linux/inotify_stubs.c && \
    make UISTYLE=text NATIVE=true STATIC=true && \
    cp src/unison src/unison-fsmonitor /usr/local/bin && \
    apk del .build-dependencies ocaml && \
    rm -rf /tmp/unison-${UNISON_VERSION}

ENV HOME="/home/www-data"
RUN addgroup -g 82 -S www-data \
  && adduser -u 82 -D -S -G www-data www-data \
  && mkdir -p ${HOME}/.unison

# Copy the profile
COPY drupal.prf ${HOME}/.unison/drupal.prf
RUN chown -R www-data:www-data ${HOME}

# Copy the bg-sync script into the container.
COPY sync.sh /usr/local/bin/bg-sync
RUN chmod +x /usr/local/bin/bg-sync

USER www-data
CMD ["bg-sync"]
