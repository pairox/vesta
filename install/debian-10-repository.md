# Debian 10 Vesta repository

Vesta updates are installed by `apt`, so the GitHub source repository is not
enough by itself. Build the `vesta`, `vesta-nginx`, `vesta-php`,
`vesta-ioncube` and `vesta-softaculous` Debian packages, then publish them as
an APT repository over HTTP(S).

The installer writes this source line:

```text
deb <UPDATE_REPO_URL>/buster/ buster vesta
```

For example:

```bash
VESTA_RHOST=https://pairox.github.io/vesta/apt \
VESTA_CHOST=https://pairox.github.io/vesta/files \
bash install/vst-install-debian.sh
```

The APT repository must expose this layout:

```text
apt/
  buster/
    dists/
      buster/
        Release
        Release.gpg
        vesta/
          binary-amd64/
            Packages
            Packages.gz
    pool/
      vesta_*.deb
      vesta-nginx_*.deb
      vesta-php_*.deb
      vesta-ioncube_*.deb
      vesta-softaculous_*.deb
```

The config/update files endpoint must expose:

```text
files/
  deb_signing.key
  latest.txt
  debian/
    10/
      templates.tar.gz
  3rdparty/
    softaculous_install.inc
```

## Publishing on GitHub Pages

1. Build or copy the Vesta runtime directories.

On an existing Debian 9 Vesta server they are usually here:

```text
/usr/local/vesta/nginx
/usr/local/vesta/php
/usr/local/vesta/ioncube
/usr/local/vesta/softaculous
```

The `vesta` package is built from this source tree. The other packages are
built from those runtime directories:

```bash
apt-get install -y build-essential gcc rsync dpkg-dev apt-utils gnupg
./install/build-deb-packages.sh dist/deb
```

If there is no existing Vesta server, build the internal runtime from source:

```bash
apt-get install -y build-essential gcc make curl ca-certificates rsync \
    dpkg-dev apt-utils gnupg libpcre3-dev zlib1g-dev libssl-dev \
    libcurl4-openssl-dev libxml2-dev

./install/build-vesta-runtime-from-source.sh dist/deb
```

By default it builds:

```text
nginx 1.24.0
PHP   5.6.40
```

You can override versions:

```bash
NGINX_VERSION=1.24.0 PHP_VERSION=5.6.40 \
./install/build-vesta-runtime-from-source.sh dist/deb
```

## Building with GitHub Actions

The workflow `.github/workflows/build-deb.yml` builds the packages inside a
Debian 10 Docker container.

Manual run:

1. Open `Actions`.
2. Select `Build Debian Packages`.
3. Click `Run workflow`.
4. Keep defaults or set versions:
   - `nginx_version`: `1.24.0`
   - `php_version`: `5.6.40`
   - `deb_version`: `1.0.0-10`
5. Download the `vesta-debian10-debs` artifact from the finished workflow run.

The artifact contains the `.deb` files that should be copied to `dist/deb/`
before publishing the APT repository:

```bash
mkdir -p dist/deb
unzip vesta-debian10-debs.zip -d dist/deb
SIGNING_KEY_ID=<your-gpg-key-id> ./install/build-github-pages-apt-repo.sh dist/deb docs
```

If the runtime directories are not in `/usr/local/vesta`, pass them explicitly:

```bash
VESTA_NGINX_DIR=/path/to/nginx \
VESTA_PHP_DIR=/path/to/php \
VESTA_IONCUBE_DIR=/path/to/ioncube \
VESTA_SOFTACULOUS_DIR=/path/to/softaculous \
./install/build-deb-packages.sh dist/deb
```

2. Create or select a GPG key for signing the APT repository.
3. Run:

```bash
SIGNING_KEY_ID=<your-gpg-key-id> \
./install/build-github-pages-apt-repo.sh dist/deb docs
```

4. Commit and push `docs/`.
5. In GitHub repository settings, enable Pages from `master` / `docs`.

After Pages is enabled, install with:

```bash
VESTA_RHOST=https://pairox.github.io/vesta/apt \
VESTA_CHOST=https://pairox.github.io/vesta/files \
bash install/vst-install-debian.sh
```

GitHub Pages is enough for this because it serves static files over HTTPS.
A regular Nginx/Apache web server is also fine. The normal GitHub repository
URL, such as `https://github.com/pairox/vesta/`, is an HTML source browser and
cannot be used directly in `/etc/apt/sources.list.d/vesta.list`.
