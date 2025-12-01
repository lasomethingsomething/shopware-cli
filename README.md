# Shopware CLI

[![Hosted By: Cloudsmith](https://img.shields.io/badge/OSS%20hosting%20by-cloudsmith-blue?logo=cloudsmith&style=flat-square)](https://cloudsmith.com)

A cli which contains handy helpful commands for daily Shopware tasks

## Features

- Manage your Shopware account extensions in the CLI
- Build and validate Shopware extensions

For docs see [here](https://developer.shopware.com/docs/products/cli/)

## Docker Installation Script

Automated installation script for setting up Shopware with Docker/OrbStack/Podman.

### Quick Start
```bash
curl -fsSL https://raw.githubusercontent.com/lasomethingsomething/shopware-cli/main/scripts/install-docker.sh | bash
```

Or clone and run:
```bash
git clone https://github.com/lasomethingsomething/shopware-cli.git
cd shopware-cli
chmod +x scripts/install-docker.sh
./scripts/install-docker.sh
```

### Features

- Automatic detection of Docker, OrbStack, or Podman
- Interactive configuration (PHP, Node, web server versions)
- Optional Minio S3 storage
- Optional XDebug debugging
- Optional production image proxy
- OrbStack routing support
- Full prerequisite checks
```

That's it! The script will be live at:
```
https://raw.githubusercontent.com/lasomethingsomething/shopware-cli/main/scripts/install-docker.sh

## Contributing

Contributions are always welcome!

