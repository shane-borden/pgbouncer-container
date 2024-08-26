# docker build -t pgbouncer-container:1.22.1 --build-arg REPO_TAG=1.22.1 .
# This image is made to work with the related gke helm chart.
# no config files exist because they are modified later

# Buildup pgbouncer
FROM debian:bookworm-slim AS builder
ARG REPO_TAG

RUN apt-get update \
	&& apt-get upgrade -y \
    && apt-get install -y build-essential \
        ca-certificates \
        autoconf \
        automake \
        libtool \
        pandoc \
        udns-utils \
        libudns-dev \
        libudns0 \
        libssl-dev \
        curl \
        gcc \
        libc-dev \
        libevent-dev \
        make \
        openssl \
        pkg-config \
        python3 \
        python3-pip \
        git \
	&& apt-get autoremove -y \
	&& apt-get clean -y \
	&& rm -rf /root/.cache \
  	&& rm -rf /var/apt/lists/* \
  	&& rm -rf /var/cache/apt/* \
  	&& apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false

# Clone pgbouncer repository
RUN git clone https://github.com/pgbouncer/pgbouncer.git /tmp/pgbouncer

# Checkout the desired version
WORKDIR /tmp/pgbouncer
SHELL ["/bin/bash", "-c"]
RUN git checkout "pgbouncer_${REPO_TAG//./_}"

# Initialize and update submodules
RUN git submodule init
RUN git submodule update

# Compile
RUN ./autogen.sh
RUN ./configure --prefix=/usr --with-udns
RUN make
RUN make install

# Buildup runtime container
FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install  -o Dpkg::Options::=--force-confdef -yq --no-install-recommends git \
        libevent-dev \
        #lsb-release \
        #software-properties-common \
    # Clean up layer
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /tmp/* \
    && rm -rf /var/tmp/* \
    && rm -rf /root/.cache \
    && rm -rf /var/apt/lists/* \
    && rm -rf /var/cache/apt/* \
    && truncate -s 0 /var/log/*log
#RUN add-apt-repository "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main"
#RUN apt-get install -o Dpkg::Options::=--force-confdef -yq --no-install-recommends postgresql-client-15

# Create non-root user
ARG USERNAME=postgres
ARG USER_UID=5432
ARG USER_GID=$USER_UID

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    #
    # [Optional] Add sudo support. Omit if you don't need to install software after connecting.
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Copy necessary files from builder stage
COPY --from=builder /usr/bin/pgbouncer /usr/bin/

# Copy startup script
COPY startupBouncer.sh /usr/bin/startupBouncer.sh

# Setup directories and startup files
RUN mkdir -p /etc/pgbouncer /var/log/pgbouncer /var/run/pgbouncer && chown -R postgres /var/run/pgbouncer /etc/pgbouncer
RUN chown postgres:postgres /usr/bin/startupBouncer.sh && chmod 755 /usr/bin/startupBouncer.sh

WORKDIR /etc/pgbouncer

USER postgres
EXPOSE 5432
#CMD ["/usr/bin/pgbouncer", "/etc/pgbouncer/pgbouncer.ini"]
CMD ["/usr/bin/startupBouncer.sh"]
