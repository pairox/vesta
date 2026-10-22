# CI and local checks

Run all local checks with:

```bash
make ci
```

Targets:

- `make lint-shell`: shell syntax checks plus ShellCheck when installed.
- `make lint-php`: `php -l` for PHP files when PHP is installed.
- `make smoke-debian`: Debian release/codename/package/repository dry-run checks.
- `make test-dry-run`: installer dry-run for Debian 12.

GitHub Actions runs on pull requests, pushes to `main`, `master`, `develop`, and manual dispatch. Debian smoke jobs check out the repository on `ubuntu-latest`, then run the smoke commands in `debian:9`, `debian:10`, `debian:11`, and `debian:12` Docker containers. Debian 9, 10 and 11 containers use `archive.debian.org` sources during CI to avoid missing packages on live mirrors after archival. The shared source setup also removes the default `debian.sources` file in these archived containers so live and archive indexes cannot be mixed. Both smoke tests and APT package builds use this setup. The release workflow is manual/tag based and only produces artifacts/checksums; it never deploys to a server.
