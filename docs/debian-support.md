# Debian support status

This fork adds installer awareness for Debian 10 `buster`, Debian 11 `bullseye`, and Debian 12 `bookworm` while keeping Debian 9 `stretch` as the legacy migration source.

## Supported paths

- Fresh install dry-run/smoke: Debian 10, 11, 12.
- Fresh install on a real host: supported only after validating in a VM with the same options.
- Debian 9 in-place upgrade: experimental; use the migration document and backups.

## Package and service notes

- Debian 10 uses PHP 7.3 packages where versioned packages are available.
- Debian 11 uses PHP 7.4 from the distribution defaults.
- Debian 12 uses PHP 8.2 from the distribution defaults; legacy Vesta PHP code must pass `php -l`, but runtime deprecations may still need web UI testing.
- Debian 10+ prefers MariaDB/default MySQL metapackages instead of old MySQL-only names.
- Debian 11/12 repository entries use keyrings and `signed-by` instead of `apt-key`.
- Firewall defaults remain iptables-compatible. Debian 12 also installs `nftables`; use `iptables-legacy` if existing Vesta rules require legacy semantics.

## Safe installer smoke mode

Set both or either of these variables before running the Debian installer:

```bash
VESTA_CI=1 VESTA_DRY_RUN=1 bash install/vst-install-debian.sh --interactive no
```

In dry-run mode the installer only prints release detection, repository lines, and package list. It does not install packages, edit `/etc`, start services, create users, or change firewall state.
