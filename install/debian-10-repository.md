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

1. Build the Debian packages and put them into `dist/deb/`.
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
