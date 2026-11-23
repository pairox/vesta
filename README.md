# Vesta Control Panel for Debian 12

This repository is a community fork of [Vesta Control Panel](https://github.com/outroll/vesta). It keeps the familiar Vesta hosting control panel while adding support for Debian 12 (`bookworm`).

The Debian 12 build is available for `amd64` and uses the distribution's current system packages, including PHP 8.2.

## Debian 12 panel runtime

The Bookworm packages build the panel binaries from Nginx 1.30.7 and PHP 8.2.36. The web stack used by hosted sites is managed separately. During an upgrade from the original standalone panel config, the package converts `ssl on;` to the SSL flag on the existing `listen` directive and checks the result before restarting Vesta. For custom configs with several server blocks, convert the old SSL directives manually before installing.

If the panel already loads ionCube or has Softaculous installed, stage the Linux x86-64 PHP 8.2 Loader at `/usr/local/vesta/ioncube/ioncube_loader_lin_8.2.so` before installing `vesta-php`. The package checks that the new PHP can load it and updates the panel's `php.ini`. Test your installed Softaculous build with the new PHP and Loader on a copy before upgrading production, since encrypted files also have to support PHP 8.2.

## Upgrade an existing installation

Back up your Vesta configuration and user data before upgrading. Then add this fork's APT repository and update the Vesta packages:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates

echo 'deb [trusted=yes] https://pairox.github.io/vesta/ bookworm vesta' \
  | sudo tee /etc/apt/sources.list.d/vesta-fork.list

sudo apt-get update
sudo apt-get install --only-upgrade vesta vesta-nginx vesta-php
```

The published repository is currently unsigned, which is why the source uses `trusted=yes`. Only add it if you trust this fork and its GitHub Pages repository.

For a major operating-system upgrade, especially from Debian 9, a fresh Debian 12 server followed by a Vesta data migration is strongly recommended. See the [Debian 9 to Debian 12 upgrade guide](docs/debian-upgrade-9-to-12.md) for details.

## Support status

- Debian 12 (`bookworm`): supported by this fork.
- Debian 10 (`buster`) and Debian 11 (`bullseye`): recognized by the installer and covered by smoke tests.
- Debian 9 (`stretch`): retained as a legacy migration source.

More details are available in the [Debian support notes](docs/debian-support.md) and [APT repository documentation](docs/apt-repository.md).

## License

Vesta Control Panel is distributed under the [GNU General Public License v3](LICENSE).
