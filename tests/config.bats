#!/usr/bin/env bats

setup() {
  load "$BATS_PLUGIN_PATH/load.bash"
  # shellcheck source=lib/file-cache.bash
  . "$PWD/lib/file-cache.bash"

  export BUILDKITE_PLUGIN_FILE_CACHE_PATH="~/.npm"
  export BUILDKITE_COMMIT="0123456789abcdef"
  export TMPDIR="$BATS_TEST_TMPDIR"
  CONFIG_FILE=""
}

teardown() {
  if [[ -n "$CONFIG_FILE" ]]; then
    rm -f "$CONFIG_FILE"
  fi
}

@test "renders the rolling cache definition" {
  CONFIG_FILE="$(file_cache_create_config)"

  run cat "$CONFIG_FILE"

  assert_success
  assert_line '  - name: "file_cache"'
  assert_line '      - "file-cache-v1"'
  assert_line '      - agent: pipeline'
  assert_line '      - agent: branch'
  assert_line '      - agent: os'
  assert_line '      - agent: arch'
  assert_line '        fallback_limit: true'
  assert_line '      - env: BUILDKITE_PLUGIN_FILE_CACHE_GENERATION'
  assert_line "      - '~/.npm'"
}

@test "quotes apostrophes in paths for YAML" {
  export BUILDKITE_PLUGIN_FILE_CACHE_PATH="cache's files"
  CONFIG_FILE="$(file_cache_create_config)"

  run cat "$CONFIG_FILE"

  assert_success
  assert_line "      - 'cache''s files'"
}

@test "rejects protected paths" {
  export BUILDKITE_PLUGIN_FILE_CACHE_PATH="/"

  run file_cache_create_config

  assert_failure
  assert_output --partial "Refusing to cache protected path"
}

@test "rejects protected path aliases" {
  for protected_path in "////" "./" "~//" "$HOME/" "$PWD/"; do
    export BUILDKITE_PLUGIN_FILE_CACHE_PATH="$protected_path"

    run file_cache_create_config

    assert_failure
    assert_output --partial "Refusing to cache protected path"
  done
}

@test "rejects paths containing newlines" {
  export BUILDKITE_PLUGIN_FILE_CACHE_PATH=$'cache\npath'

  run file_cache_create_config

  assert_failure
  assert_output --partial "must not contain newlines"
}

@test "exports the Buildkite commit as the cache generation" {
  file_cache_export_generation

  assert_equal "$BUILDKITE_PLUGIN_FILE_CACHE_GENERATION" "$BUILDKITE_COMMIT"
}

@test "resolves home-relative paths for save checks" {
  export HOME="$BATS_TEST_TMPDIR/home"

  run file_cache_resolve_path

  assert_success
  assert_output "$HOME/.npm"
}
