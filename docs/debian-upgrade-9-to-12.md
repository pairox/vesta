# Debian 9 to Debian 12 upgrade guide for Vesta

## Support statement

Recommended: build a new Debian 12 server, install this fork, then migrate users, domains, mail, DNS zones, databases, and SSL material from the Debian 9 host.

Experimental: in-place upgrade Debian 9 -> 10 -> 11 -> 12. Do this only in a VM clone first. Never run destructive commands on a production Vesta server without a verified backup and explicit operator confirmation.

## Backup checklist

Back up at minimum:

- `/usr/local/vesta`
- `/home`
- `/etc/nginx`, `/etc/apache2`, `/etc/exim4`, `/etc/dovecot`, `/etc/bind`, `/etc/mysql`, `/etc/php*`
- `/var/mail`, `/var/spool/mail`, mail users under `/home/*/mail`
- `/var/lib/mysql` plus a logical `mysqldump --all-databases --routines --events`
- `/root/.my.cnf`, `/etc/passwd`, `/etc/group`, `/etc/shadow`, `/etc/gshadow`
- DNS zones, cron files, SSL certificates, custom templates, firewall rules.

Use:

```bash
sudo tools/preflight-debian-upgrade.sh --dry-run
sudo tools/backup-vesta-before-upgrade.sh --dry-run
sudo tools/backup-vesta-before-upgrade.sh --dest /root/vesta-upgrade-backup-YYYYMMDD
```

Verify archives and copy them off-server before upgrading.

## Preflight checks

- Confirm console/KVM access independent of SSH.
- Confirm free disk space for two full backups.
- Confirm package state with `dpkg --audit` and `apt-get -s dist-upgrade`.
- Confirm all Vesta backups complete and a restore path is tested.
- Disable third-party repositories until each Debian release upgrade is complete.

## Known risks

- PHP 8.2 can expose legacy runtime deprecations.
- `apt-key` repositories must be converted to keyrings before Debian 11/12.
- iptables may be backed by nftables; Vesta rules may require `iptables-legacy`.
- MariaDB authentication tables and MySQL grants can differ across releases.
- Roundcube/phpMyAdmin configuration formats changed across Debian releases.

## In-place outline

For each hop (9 -> 10, 10 -> 11, 11 -> 12):

1. Run preflight and backup scripts.
2. Edit APT sources to the next codename only after backups are off-host.
3. Run `apt-get update`, then `apt-get upgrade`, then `apt-get dist-upgrade` from a console.
4. Reboot and inspect `systemctl --failed`.
5. Run `tools/repair-after-debian-upgrade.sh --dry-run`, then run it without dry-run only after reviewing actions.
6. Test panel login, DNS, web, mail, FTP, cron, backups, and database access before continuing.

## Rollback notes

Fast rollback is restore-from-image/snapshot. File-level restore is possible only when the OS and package versions remain compatible. Keep the Debian 9 host untouched if using the recommended migration approach.
