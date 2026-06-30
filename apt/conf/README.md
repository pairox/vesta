# APT repository input

Place built `.deb` packages under `apt/pool/` before running the APT repository workflow. The workflow copies packages into the generated `pool/vesta/<architecture>/` layout and publishes `dists/<codename>/Release`, `InRelease`, `Release.gpg`, `Packages`, and `Packages.gz` to GitHub Pages.

Do not place private signing keys in this directory. Store the armored private key in the `APT_GPG_PRIVATE_KEY` GitHub Actions secret and, if needed, the passphrase in `APT_GPG_PASSPHRASE`.
