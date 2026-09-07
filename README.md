# File Cache Buildkite Plugin

Automatically restore and save one path with [Buildkite Cache](https://buildkite.com/docs/pipelines/configure/cache).

This plugin wraps the agent's path-based cache commands so a pipeline author only needs to choose the folder to cache. The agent supplies the default cache configuration. Buildkite hosted agents provide storage automatically; self-hosted agents can use an Amazon S3 or S3-compatible store.

## Example

```yaml
steps:
  - label: ":nodejs: Test"
    command: "npm ci && npm test"
    plugins:
      - buildkite-plugins/file-cache#v0.1.0:
          path: "~/.npm"
```

The plugin restores the path before the command and saves it after a successful command. It does not require a repository `.buildkite/cache.yml`, explicit restore/save commands, or a registry selection.

## Requirements

- Buildkite Cache must be enabled for the organization.
- A Buildkite agent version that supports `buildkite-agent cache save/restore --path`.
- Bash and `buildkite-agent` must be available in the job environment.
- Self-hosted agents require an Amazon S3 or S3-compatible cache store and ambient AWS credentials.

## Configuration

### `path` (required, string)

The file or directory to restore and save. Relative paths resolve from the job working directory. Home-relative paths such as `~/.npm` and absolute paths are passed through to Buildkite Cache.

The filesystem root, current working directory, and entire home directory are rejected. Buildkite Cache applies its own additional target-path safety checks.

### `store` (optional, string)

The cache store URL for a self-hosted agent. Use an existing bucket, an optional object key prefix, and the bucket's region:

```text
s3://<bucket>/<optional-prefix>?region=<region>
```

For example:

```yaml
steps:
  - label: ":nodejs: Test"
    command: "npm ci && npm test"
    plugins:
      - buildkite-plugins/file-cache#v0.1.0:
          path: "~/.npm"
          store: "s3://acme-buildkite-cache/buildkite?region=ap-southeast-2"
```

The plugin passes this value to `buildkite-agent cache` as `--cache-store-url`. It does not parse the URL or use the AWS CLI. A configured `store` takes precedence over `BUILDKITE_AGENT_CACHE_STORE_URL`.

Do not put AWS credentials in the store URL. Buildkite hosted agents provide their cache store automatically, so the plugin rejects this option on hosted agents.

## Self-hosted agents

The Buildkite agent uploads and downloads the cache using the AWS SDK's ambient credential chain. Prefer an EC2 instance profile, ECS task role, EKS workload identity, or another short-lived workload identity. The file-cache plugin does not accept or manage AWS credentials.

Every agent using the same cache registry must use the same store. For a fleet-wide configuration, set the store in the agent service environment or an agent `environment` hook:

```shell
export BUILDKITE_AGENT_CACHE_STORE_URL="s3://acme-buildkite-cache/buildkite?region=ap-southeast-2"
```

Pipeline authors can then keep the path-only configuration from the first example. If neither `store` nor `BUILDKITE_AGENT_CACHE_STORE_URL` is present on a self-hosted job, the plugin fails before the command with a setup error.

### Authenticate with Buildkite OIDC

Agents without an existing AWS workload identity can compose this plugin with the [AWS assume-role-with-web-identity plugin](https://github.com/buildkite-plugins/aws-assume-role-with-web-identity-buildkite-plugin):

```yaml
steps:
  - label: ":nodejs: Test"
    command: "npm ci && npm test"
    plugins:
      - buildkite-plugins/aws-assume-role-with-web-identity#v1.7.0:
          role-arn: "arn:aws:iam::123456789012:role/buildkite-cache"
          session-tags:
            - organization_slug
            - pipeline_slug
      - buildkite-plugins/file-cache#v0.1.0:
          path: "~/.npm"
          store: "s3://acme-buildkite-cache/buildkite?region=ap-southeast-2"
```

Use the OIDC plugin's default `environment` hook and default credential names. It exports temporary `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_SESSION_TOKEN` values before this plugin restores the cache. Set its role session duration long enough for the credentials to remain valid through this plugin's post-command save.

### Grant access to the cache prefix

The agent needs permission to download, upload, abort incomplete multipart uploads, and copy cache objects within the configured prefix. A minimal starting point is:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:AbortMultipartUpload"
      ],
      "Resource": "arn:aws:s3:::acme-buildkite-cache/buildkite/*"
    }
  ]
}
```

Buckets encrypted with a customer-managed AWS KMS key also need the corresponding KMS permissions.

Configure an S3 lifecycle rule for the same prefix that expires current objects after three days and aborts incomplete multipart uploads. If bucket versioning is enabled, expire noncurrent versions too. Buildkite expires registry metadata but cannot delete objects from a customer-managed store.

For an S3-compatible service, add its endpoint and path-style setting to the store URL:

```yaml
store: "s3://build-cache/buildkite?region=us-east-1&endpoint=https://minio.example.com&use_path_style=true"
```

## Choosing a path

Use this plugin for data that is safe to regenerate, particularly package-manager download caches and compiler caches:

- `~/.npm`
- `~/.cache/pip`
- `~/.cache/go-build`
- `~/.cargo/registry`

Avoid secrets, credentials, required build artifacts, and broad directories whose download and extraction cost may exceed the work they save.

## Security and isolation

The default cache registry policy permits sharing across pipelines and branches in the cluster. Cache keys are not an authorization boundary. Before using the plugin with untrusted builds, configure the cache registry policy to prevent untrusted jobs from reading or replacing trusted cache entries.

## Cache volumes are different

The hosted-agent `cache:` pipeline attribute configures an attached best-effort cache volume. This plugin uses the key-based Buildkite Cache service, which archives the selected path and can restore it on a different agent instance.

## Container limitation

The hooks run on the agent host. A path used only inside a Docker container must also be visible at the same host path. Direct restoration into a bind-mount root is not supported by the plugin.

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
