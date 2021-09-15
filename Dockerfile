FROM ubuntu:20.04

# Install git tz and build-base
RUN apt-get update

ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Mexico_City

RUN apt-get install -y build-essential automake autoconf cmake git libmbedtls-dev squashfs-tools ssh-askpass pkg-config curl apt-transport-https ca-certificates gnupg lsb-release libwxgtk3.0-gtk3-dev libssl-dev libncurses5-dev tzdata

RUN ln -sf /usr/lib/x86_64-linux-gnu/libmbedcrypto.so /usr/lib/x86_64-linux-gnu/libmbedcrypto.so.1

# Install asdf 
RUN adduser --shell /bin/bash --home /asdf --disabled-password asdf
ENV PATH="${PATH}:/asdf/.asdf/shims:/asdf/.asdf/bin"

ENV LANG C.UTF-8

WORKDIR /asdf/opex62541

ADD . .

RUN chown -R asdf:asdf /asdf/opex62541

USER asdf

RUN git clone https://github.com/asdf-vm/asdf.git /asdf/.asdf --branch v0.8.0  && \
    echo '. /asdf/.asdf/asdf.sh' >> /asdf/.bashrc && \
    echo '. /asdf/.asdf/asdf.sh' >> /asdf/.profile

# Install Erlang
RUN asdf plugin-add erlang
RUN asdf install erlang 24.0.6
RUN asdf global erlang 24.0.6

# Install Elixir
RUN asdf plugin-add elixir
RUN asdf install elixir 1.12.2-otp-24
RUN asdf global elixir 1.12.2-otp-24

RUN mix local.hex --force && \
  mix local.rebar --force

USER asdf

RUN mix deps.get && mix compile