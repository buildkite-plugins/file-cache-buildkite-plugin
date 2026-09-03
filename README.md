# File Cache Buildkite Plugin

Automatically restore and save one path with [Buildkite Cache](https://buildkite.com/docs/pipelines/configure/cache).

This plugin is an early hosted-agent prototype. It supplies rolling, platform-aware cache defaults so a pipeline author only needs to choose the folder to cache.

## Example

```yaml
steps:
  - label: ":nodejs: Test"
    command: "npm ci && npm test"
    plugins:
      - buildkite-plugins/file-cache#v0.1.0:
          path: "~/.npm"
```

The plugin restores the path before the command and saves it after a successful command. It does not require a repository `.buildkite/cache.yml`, explicit restore/save commands, storage credentials, or a registry selection on Buildkite hosted agents.

## Requirements

- Buildkite Cache must be enabled for the organization.
- Buildkite agent 3.136.3 or later.
- Bash and `buildkite-agent` must be available in the job environment.
- The initial supported environment is a POSIX Buildkite hosted agent. Self-hosted agents still need a configured cache store.

## Configuration

### `path` (required, string)

The file or directory to restore and save. Relative paths resolve from the job working directory. Home-relative paths such as `~/.npm` and absolute paths are passed through to Buildkite Cache.

The filesystem root, current working directory, and entire home directory are rejected. Buildkite Cache applies its own additional target-path safety checks.

## Default behaviour

The plugin creates a temporary cache definition equivalent to:

```yaml
caches:
  - name: "file_cache"
    cache_key:
      - "file-cache-v1"
      - agent: pipeline
      - agent: branch
      - agent: os
      - "~/.npm"
      - agent: arch
        fallback_limit: true
      - env: BUILDKITE_PLUGIN_FILE_CACHE_GENERATION
    target_paths:
      - "~/.npm"
```

The generation is the checked-out commit. Restore checks the exact commit first and then the newest compatible entry for the same pipeline, branch, operating system, architecture, and target path.

- A normal cache miss does not fail the job.
- A restore error fails before the command runs.
- A failed command is never saved.
- A missing path at save time produces a warning and is skipped.
- A save error produces a warning but does not change a successful command into a failed job.

## Choosing a path

Use this plugin for data that is safe to regenerate, particularly package-manager download caches and compiler caches:

- `~/.npm`
- `~/.cache/pip`
- `~/.cache/go-build`
- `~/.cargo/registry`

Avoid secrets, credentials, required build artifacts, and broad directories whose download and extraction cost may exceed the work they save.

## Security and isolation

The generated key includes the pipeline and branch to avoid accidental sharing in the prototype. Cache keys are not an authorization boundary. Before using the plugin with untrusted builds, configure the cache registry policy to prevent untrusted jobs from reading or replacing trusted cache entries.

## Cache volumes are different

The hosted-agent `cache:` pipeline attribute configures an attached best-effort cache volume. This plugin uses the key-based Buildkite Cache service, which archives the selected path and can restore it on a different agent instance.

## Container limitation

The hooks run on the agent host. A path used only inside a Docker container must also be visible at the same host path. Direct restoration into a bind-mount root is not supported by the prototype.

## Developing

Run the BATS suite:

```shell
docker compose run --rm tests
```

Run ShellCheck and the Buildkite plugin linter:

```shell
docker compose run --rm shellcheck
docker compose run --rm lint
```
