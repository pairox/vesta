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

GitHub Actions runs on pull requests, pushes to `main`, `master`, `develop`, and manual dispatch. Debian smoke jobs use `debian:9`, `debian:10`, `debian:11`, and `debian:12` containers. The release workflow is manual/tag based and only produces artifacts/checksums; it never deploys to a server.
