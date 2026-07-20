<div align="center">
  <img src="https://raw.githubusercontent.com/valiot/opex62541/master/assets/images/opex62541-logo.png" alt="opex62541 Logo" width="512" height="151" />
</div>

***
<br>
<div align="center">
  <img src="https://raw.githubusercontent.com/valiot/opex62541/master/assets/images/valiot-logo-blue.png" alt="Valiot Logo" width="384" height="80" />
</div>
<br>

Opex62541 is an Elixir wrapper for the [open62541](https://github.com/open62541/open62541) library; open62541 is an open-source implementation of OPC UA (OPC Unified Architecture) aka IEC 62541 licensed under Mozilla Public License v2.0.

## Content

- [Features](#features)
- [Installation](#installation)
  - [Compatibility](#compatibility)
  - [Nerves](#nerves)
  - [Customized build](#customized-build)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)
- [TODO](#TODO)

## Features

This library implements the following features from [open62541](https://github.com/open62541/open62541):
- Communication Stack
  - OPC UA binary protocol
  - Secure communication with encrypted messages
- Server
  - Support for all OPC UA node types
  - Access control for individual nodes
  - Support for adding and removing nodes and references also at runtime.
  - Support for inheritance and instantiation of object and variable-types.
  - Support for subscriptions/monitored items.
- Client
  - All OPC UA services supported
  - Support for subscriptions/monitored items.

## Installation

To install this package, add `opex62541` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:opex62541, "~> 0.1.2"}
  ]
end
```

### Breaking Changes (v1.4.x Migration)

**Important:** This library now uses open62541 v1.4.12 with **OpenSSL** as the encryption backend instead of mbedTLS.

**System Dependencies Required:**

- **Ubuntu/Debian:**
  ```bash
  sudo apt-get install git build-essential gcc pkg-config cmake python libssl-dev
  ```

- **Arch Linux:**
  ```bash
  sudo pacman -S git base-devel gcc pkg-config cmake python openssl
  ```

- **Nerves:** OpenSSL is already included in the Nerves system. No additional configuration needed.

**Backward Compatibility:**

If you need to use the legacy v1.0 with mbedTLS for existing projects, set the environment variable:

```bash
export OPEN62541_DOWNLOAD_VERSION=v1.0
```

Note: v1.0 requires mbedTLS instead of OpenSSL. Install with:
```bash
sudo apt-get install libmbedtls-dev  # Ubuntu/Debian
```

### Compatibility

Opex62541 is now based on open62541 v1.4.14 with Elixir 1.10.0+. It was tested on:
  * Ubuntu 18.04, 20.04, 22.04
  * Raspbian OS (Raspberry Pi 3B+)
  * Nerves (Raspberry Pi 3B+)

### Nerves

[Nerves](https://www.nerves-project.org) is a complete IoT platform and infrastructure to build and deploy maintainable embedded systems to boards such as Raspberry Pi or Beaglebone.

**Good news:** OpenSSL is already included in standard Nerves systems. No additional configuration or custom system is required for `opex62541` to work with encryption enabled.

### Customized builds

By default, Opex62541 downloads and compiles the `v1.4.14` release of open62541 with OpenSSL encryption. If you want to compile it manually or change the default version, use the following example commands to set the desired env variables:

```bash
export MANUAL_BUILD=true

export OPEN62541_DOWNLOAD_VERSION=v1.4.14
```
The open62541 project uses CMake to manage the build options for code generation and to generate build projects for the different systems and IDEs. To overwrite the default options, use `OPEN62541_BUILD_ARGS` as follows:

```bash
export OPEN62541_BUILD_ARGS='-DCMAKE_BUILD_TYPE=Release -DUA_NAMESPACE_ZERO=MINIMAL'
```

Default values for `OPEN62541_BUILD_ARGS` are `-DBUILD_SHARED_LIBS=ON -DCMAKE_BUILD_TYPE=RelWithDebInfo -DUA_NAMESPACE_ZERO=FULL -DUA_LOGLEVEL=601 -DUA_ENABLE_DISCOVERY_MULTICAST=ON -DUA_ENABLE_AMALGAMATION=ON -DUA_ENABLE_ENCRYPTION=OPENSSL`.

## Docker Container

To build the container locally use:

```bash
git clone https://github.com/valiot/opex62541
cd opex62541
docker build -t <name:tag> .
```

You can use this container to test this application. 

## Documentation

For detailed documentation and tutorials refer to [hexdocs.pm](https://hexdocs.pm/opex62541).

## Contributing
  * Fork our repository on Github.
  * Fix or add what is needed.
  * Commit to your repository
  * Issue a Github Pull Request.
  * Fill the pull request template.

If you wish to clone this repository, use:
```
git clone https://github.com/valiot/opex62541.git
```

## License

See [LICENSE](https://github.com/valiot/opex62541/blob/master/LICENSE).

## TODO
  * **Methods**
  * **OPC UA PubSub**
  * **Better C code handling for the Client and Server common code**