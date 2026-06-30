# Publishing a Vesta APT repository on GitHub Pages

This repository can publish Debian packages in the same APT layout that Vesta installers expect from `apt.vestacp.com`: `dists/<codename>/InRelease`, `dists/<codename>/Release`, and `dists/<codename>/<component>/binary-<arch>/Packages.gz`.

## 1. Add packages

Copy built packages into `apt/pool/` and commit them. The workflow accepts packages for multiple architectures and moves them into the generated `pool/<component>/<arch>/` tree.

The workflow also builds the `vesta` package from the current repository and adds it to the generated pool automatically. Packages that contain bundled binaries, such as `vesta-nginx` and `vesta-php`, still need to be built separately and committed under `apt/pool/` if you want to publish replacements for them.

The workflow can also run before the first package is committed. In that case it publishes an empty `amd64` repository so GitHub Pages deployment succeeds, and later `.deb` pushes replace it with package indexes.

```bash
cp build/*.deb apt/pool/
git add apt/pool/*.deb
git commit -m "Add Debian packages"
git push
```

## 2. Add a signing key

APT should use a signed repository. Generate or reuse an OpenPGP key, then add these GitHub Actions secrets:

- `APT_GPG_PRIVATE_KEY`: ASCII-armored private key exported with `gpg --armor --export-secret-keys <KEYID>`.
- `APT_GPG_PASSPHRASE`: passphrase for that key, if it has one.

The public key should be published for users, for example as `vesta-archive-keyring.gpg` in the GitHub Pages site or as a release asset.

## 3. Enable GitHub Pages

In the GitHub repository settings, open **Settings** -> **Pages** and set **Build and deployment** -> **Source** to **GitHub Actions**. Run the **Publish APT repository** workflow manually with codename `stretch buster`, or push a `.deb` under `apt/pool/`. Publishing both suites keeps Debian 9 clients on `stretch` and Debian 10 clients on `buster`.

If `actions/deploy-pages` fails with `HttpError: Not Found` and `Ensure GitHub Pages has been enabled`, Pages is not enabled for the repository or the source is not set to **GitHub Actions** yet. Fix the repository setting first, then rerun the workflow.

The published URL will look like this:

```text
https://<owner>.github.io/<repo>/dists/buster/InRelease
```

## 4. Configure clients

For a repository published at `https://<owner>.github.io/<repo>/`, clients can use:

```bash
curl -fsSL https://<owner>.github.io/<repo>/vesta-archive-keyring.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/vesta-archive-keyring.gpg

echo 'deb [signed-by=/usr/share/keyrings/vesta-archive-keyring.gpg] https://<owner>.github.io/<repo>/ buster vesta' \
  | sudo tee /etc/apt/sources.list.d/vesta.list

sudo apt-get update
```

If the workflow was run without `APT_GPG_PRIVATE_KEY`, it publishes only an unsigned `Release` file. That mode is useful for local testing, but production clients should use the signed `InRelease` generated when the signing key secret is configured.

## Local test

Build the repository locally before pushing:

```bash
sudo apt-get update
sudo apt-get install -y apt-utils dpkg-dev gnupg
./scripts/build-apt-repository.sh --input apt/pool --output public --codename stretch --component vesta
```

To test the empty-repository path, pass `--allow-empty`. Use `--architecture` to publish a different empty architecture index.

Build the local `vesta` package with:

```bash
./scripts/build-vesta-deb.sh --output apt/pool
```
