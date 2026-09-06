#!/usr/bin/env bats

setup() {
  load "$BATS_PLUGIN_PATH/load.bash"
  # shellcheck source=lib/file-cache.bash
  . "$PWD/lib/file-cache.bash"

  export BUILDKITE_PLUGIN_FILE_CACHE_PATH="~/.npm"
}

@test "returns the configured path" {
  run file_cache_path

  assert_success
  assert_output "~/.npm"
}

@test "returns the configured cache store" {
  export BUILDKITE_PLUGIN_FILE_CACHE_STORE="s3://build-cache/buildkite?region=ap-southeast-2"

  run file_cache_store_url

  assert_success
  assert_output "$BUILDKITE_PLUGIN_FILE_CACHE_STORE"
}

@test "uses the agent cache store when the plugin store is not configured" {
  export BUILDKITE_COMPUTE_TYPE="self-hosted"
  export BUILDKITE_AGENT_CACHE_STORE_URL="s3://build-cache/buildkite?region=ap-southeast-2"

  run file_cache_store_url

  assert_success
  assert_output ""
}

@test "requires a cache store on self-hosted agents" {
  export BUILDKITE_COMPUTE_TYPE="self-hosted"
  unset BUILDKITE_AGENT_CACHE_STORE_URL

  run file_cache_store_url

  assert_failure
  assert_output --partial "set the plugin store option or BUILDKITE_AGENT_CACHE_STORE_URL"
}

@test "rejects a custom cache store on hosted agents" {
  export BUILDKITE_COMPUTE_TYPE="hosted"
  export BUILDKITE_PLUGIN_FILE_CACHE_STORE="s3://build-cache/buildkite"

  run file_cache_store_url

  assert_failure
  assert_output --partial "only supported on self-hosted agents"
}

@test "rejects cache stores containing newlines" {
  export BUILDKITE_PLUGIN_FILE_CACHE_STORE=$'s3://build-cache/buildkite\nother'

  run file_cache_store_url

  assert_failure
  assert_output --partial "must not contain newlines"
}

@test "rejects protected paths" {
  export BUILDKITE_PLUGIN_FILE_CACHE_PATH="/"

  run file_cache_path

  assert_failure
  assert_output --partial "Refusing to cache protected path"
}

@test "rejects protected path aliases" {
  for protected_path in "////" "./" "~//" "$HOME/" "$PWD/"; do
    export BUILDKITE_PLUGIN_FILE_CACHE_PATH="$protected_path"

    run file_cache_path

    assert_failure
    assert_output --partial "Refusing to cache protected path"
  done
}

@test "rejects paths containing newlines" {
  export BUILDKITE_PLUGIN_FILE_CACHE_PATH=$'cache\npath'

  run file_cache_path

  assert_failure
  assert_output --partial "must not contain newlines"
}

@test "resolves home-relative paths for save checks" {
  export HOME="$BATS_TEST_TMPDIR/home"

  run file_cache_resolve_path

  assert_success
  assert_output "$HOME/.npm"
}
