#!/usr/bin/env bats

setup() {
  load "$BATS_PLUGIN_PATH/load.bash"

  export BUILDKITE_PLUGIN_FILE_CACHE_PATH="cache/npm"
}

@test "restores the configured path" {
  stub buildkite-agent \
    "cache restore --path cache/npm : echo restored"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial "Restoring file cache"
  assert_output --partial "restored"

  unstub buildkite-agent
}

@test "restores from the configured cache store" {
  export BUILDKITE_COMPUTE_TYPE="self-hosted"
  export BUILDKITE_AGENT_CACHE_STORE_URL="s3://agent-wide-cache/buildkite?region=us-east-1"
  export BUILDKITE_PLUGIN_FILE_CACHE_STORE="s3://build-cache/buildkite?region=ap-southeast-2&endpoint=https://minio.example.com&use_path_style=true"
  stub buildkite-agent \
    "cache restore --path cache/npm --cache-store-url s3://build-cache/buildkite?region=ap-southeast-2\\&endpoint=https://minio.example.com\\&use_path_style=true : echo restored"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial "restored"

  unstub buildkite-agent
}

@test "uses an agent-wide cache store without forwarding an override" {
  export BUILDKITE_COMPUTE_TYPE="self-hosted"
  export BUILDKITE_AGENT_CACHE_STORE_URL="s3://build-cache/buildkite?region=ap-southeast-2"
  stub buildkite-agent \
    "cache restore --path cache/npm : echo restored"

  run "$PWD/hooks/pre-command"

  assert_success
  assert_output --partial "restored"

  unstub buildkite-agent
}

@test "fails clearly when a self-hosted cache store is missing" {
  export BUILDKITE_COMPUTE_TYPE="self-hosted"
  unset BUILDKITE_AGENT_CACHE_STORE_URL

  run "$PWD/hooks/pre-command"

  assert_failure
  assert_output --partial "Self-hosted agents require an S3 cache store"
}

@test "fails when restore fails" {
  stub buildkite-agent \
    "cache restore --path cache/npm : exit 42"

  run "$PWD/hooks/pre-command"

  assert_failure 42

  unstub buildkite-agent
}
