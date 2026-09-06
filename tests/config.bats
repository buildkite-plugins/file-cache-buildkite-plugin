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
