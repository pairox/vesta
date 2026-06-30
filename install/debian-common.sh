#!/bin/bash
# Shared Debian helpers for Vesta installer and smoke tests.

vesta_debian_codename() {
    local release="${1:-}"
    case "$release" in
        7) echo wheezy ;;
        8) echo jessie ;;
        9) echo stretch ;;
        10) echo buster ;;
        11) echo bullseye ;;
        12) echo bookworm ;;
        *)
            if [ -r /etc/os-release ]; then
                # shellcheck source=/dev/null
                . /etc/os-release
                echo "${VERSION_CODENAME:-}"
            fi
            ;;
    esac
}

vesta_debian_php_version() {
    case "${1:-}" in
        10) echo 7.3 ;;
        11) echo 7.4 ;;
        12) echo 8.2 ;;
        9) echo 7.0 ;;
        *) echo 5 ;;
    esac
}

vesta_debian_supported() {
    case "${1:-}" in
        7|8|9|10|11|12) return 0 ;;
        *) return 1 ;;
    esac
}

vesta_debian_package_list() {
    local release="$1"
    local phpver
    phpver=$(vesta_debian_php_version "$release")
    local php_packages="php php-common php-cgi php-mysql php-curl php-fpm php-pgsql libapache2-mod-php"
    if [ "$release" -lt 9 ]; then
        php_packages="php5 php5-common php5-cgi php5-mysql php5-curl php5-fpm php5-pgsql libapache2-mod-php5"
    fi
    local db_packages="mariadb-server mariadb-client mariadb-common default-mysql-server default-mysql-client"
    if [ "$release" -lt 10 ]; then
        db_packages="mysql-server mysql-common mysql-client"
    fi
    local base="nginx apache2 apache2-utils apache2-suexec-custom libapache2-mod-fcgid awstats webalizer vsftpd proftpd-basic bind9 exim4 exim4-daemon-heavy clamav-daemon spamassassin dovecot-imapd dovecot-pop3d roundcube-core roundcube-mysql roundcube-plugins postgresql postgresql-contrib phppgadmin phpmyadmin mc flex whois rssh git idn zip sudo bc ftp lsof ntpdate rrdtool quota bsdutils e2fsprogs curl ca-certificates openssl gnupg imagemagick fail2ban dnsutils bsdmainutils cron vesta vesta-nginx vesta-php expect libmail-dkim-perl unrar-free vim-common vesta-ioncube vesta-softaculous net-tools unzip iptables iptables-persistent"
    if [ "$release" -ge 12 ]; then
        base="${base/ bsdmainutils / }"
        base="$base bsdextrautils nftables"
    fi
    if [ "$release" -eq 10 ]; then
        base="$base php${phpver}-fpm php${phpver}-cli php${phpver}-mysql php${phpver}-curl php${phpver}-pgsql"
    fi
    echo "$base $php_packages $db_packages" | xargs -n1 | awk '!seen[$0]++' | xargs
}

vesta_debian_repo_lines() {
    local release="$1" codename rhost="${2:-apt.vestacp.com}"
    codename=$(vesta_debian_codename "$release")
    if [ "$release" -ge 11 ]; then
        echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/debian/ $codename nginx"
        echo "deb [signed-by=/usr/share/keyrings/vesta-archive-keyring.gpg] http://$rhost/$codename/ $codename vesta"
    else
        echo "deb http://nginx.org/packages/debian/ $codename nginx"
        echo "deb http://$rhost/$codename/ $codename vesta"
    fi
}
