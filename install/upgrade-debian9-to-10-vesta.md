# Обновление Debian 9 до Debian 10 с Vesta

Debian 10 buster уже снят с обычной поддержки, поэтому перед работой нужен
snapshot/VPS backup. На живом сервере не запускай `vst-install-debian.sh`
поверх установленной Vesta: это установщик для нового сервера.

## 1. До обновления

Проверь версию и архитектуру:

```bash
cat /etc/debian_version
dpkg --print-architecture
```

Сделай резервные копии:

```bash
mkdir -p /root/pre-buster-upgrade
tar -czf /root/pre-buster-upgrade/etc.tgz /etc
tar -czf /root/pre-buster-upgrade/vesta.tgz /usr/local/vesta
tar -czf /root/pre-buster-upgrade/home.tgz /home
mysqldump --all-databases --single-transaction --routines --events > /root/pre-buster-upgrade/all-db.sql
```

Если есть место, дополнительно сохрани `/var/lib/mysql`, `/var/lib/postgresql`,
`/var/mail` и `/var/vmail`.

## 2. Подготовь свой Vesta APT repository

Перед `full-upgrade` должны существовать пакеты Vesta для `buster`:

```text
vesta
vesta-nginx
vesta-php
vesta-ioncube
vesta-softaculous
```

Опубликуй их через GitHub Pages или обычный веб-сервер. Для GitHub Pages:

```bash
SIGNING_KEY_ID=<gpg-key-id> ./install/build-github-pages-apt-repo.sh dist/deb docs
```

На сервере добавь свой ключ и buster repo:

```bash
wget -O /tmp/vesta.key https://pairox.github.io/vesta/files/deb_signing.key
apt-key add /tmp/vesta.key
echo "deb https://pairox.github.io/vesta/apt/buster/ buster vesta" > /etc/apt/sources.list.d/vesta.list
```

## 3. Обнови Vesta на Debian 9 до пакета с поддержкой buster

```bash
apt-get update
apt-get install --only-upgrade vesta vesta-nginx vesta-php
```

Проверь, что в `/usr/local/vesta/conf/vesta.conf` есть:

```text
UPDATE_REPO_URL='https://pairox.github.io/vesta/apt'
UPDATE_CONFIG_URL='https://pairox.github.io/vesta/files'
```

Если строк нет, добавь вручную.

## 4. Обнови Debian sources с stretch на buster

```bash
cp /etc/apt/sources.list /root/pre-buster-upgrade/sources.list.stretch
sed -i 's/stretch/buster/g' /etc/apt/sources.list
```

Проверь сторонние источники:

```bash
ls -1 /etc/apt/sources.list.d/
```

Все сторонние `.list`, кроме `vesta.list`, лучше временно отключить или
перевести на buster, если у них есть buster repository.

## 5. Выполни системное обновление

```bash
apt-get update
apt-get upgrade
apt-get full-upgrade
reboot
```

На вопрос про конфиги обычно безопаснее выбирать сохранение текущего файла
для сервисов Vesta: nginx, apache2, exim4, dovecot, bind9, mysql/mariadb.

## 6. После перезагрузки

```bash
cat /etc/debian_version
apt-get install --reinstall vesta vesta-nginx vesta-php
apt-get install default-mysql-server default-mysql-client php php-fpm php-mysql php-curl php-pgsql
```

Если используешь phpMyAdmin на Debian 10, нужен пакет из своего/стороннего
repo: в стандартном Debian 10 его может не быть.

Перезапусти и проверь сервисы:

```bash
systemctl restart vesta nginx apache2 mysql exim4 dovecot bind9 cron
systemctl --failed
/usr/local/vesta/bin/v-list-sys-services
/usr/local/vesta/bin/v-update-web-templates no
```

Если используешь PHP-FPM шаблоны:

```bash
find /etc/php -type d -path '*/fpm/pool.d'
systemctl restart php*-fpm
```

## 7. Проверка панели

Открой:

```text
https://<server-ip>:8083
```

Проверь:

```bash
/usr/local/vesta/bin/v-list-sys-info
/usr/local/vesta/bin/v-list-sys-vesta-updates
/usr/local/vesta/bin/v-list-web-domains admin
/usr/local/vesta/bin/v-list-mail-domains admin
```

Только после проверки можно делать:

```bash
apt-get autoremove
apt-get clean
```
