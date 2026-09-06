#!/usr/bin/env bash

file_cache_error() {
  printf '~~~ :x: %s\n' "$*" >&2
}

file_cache_warning() {
  printf '~~~ :warning: %s\n' "$*" >&2
}

file_cache_validate_path() {
  local path="$1" protected_path home_path working_path

  if [[ -z "$path" ]]; then
    file_cache_error "The file-cache plugin requires a path"
    return 1
  fi

  if [[ "$path" == *$'\n'* || "$path" == *$'\r'* ]]; then
    file_cache_error "The file-cache path must not contain newlines"
    return 1
  fi

  protected_path="$path"
  while [[ "$protected_path" != "/" && "$protected_path" == */ ]]; do
    protected_path="${protected_path%/}"
  done

  home_path="${HOME:-}"
  working_path="${PWD:-}"
  while [[ "$home_path" != "/" && "$home_path" == */ ]]; do
    home_path="${home_path%/}"
  done
  while [[ "$working_path" != "/" && "$working_path" == */ ]]; do
    working_path="${working_path%/}"
  done

  case "$protected_path" in
    / | . | '~')
      file_cache_error "Refusing to cache protected path: ${path}"
      return 1
      ;;
  esac

  if [[ -n "$home_path" && "$protected_path" == "$home_path" ]] ||
    [[ -n "$working_path" && "$protected_path" == "$working_path" ]]; then
    file_cache_error "Refusing to cache protected path: ${path}"
    return 1
  fi
}

file_cache_path() {
  local path="${BUILDKITE_PLUGIN_FILE_CACHE_PATH:-}"

  file_cache_validate_path "$path" || return 1
  printf '%s\n' "$path"
}

file_cache_resolve_path() {
  local path

  path="$(file_cache_path)" || return 1

  if [[ "$path" == '~/'* ]]; then
    if [[ -z "${HOME:-}" ]]; then
      file_cache_error "HOME is required for a home-relative cache path"
      return 1
    fi
    printf '%s/%s\n' "$HOME" "${path:2}"
  elif [[ "$path" == /* ]]; then
    printf '%s\n' "$path"
  else
    printf '%s/%s\n' "$PWD" "$path"
  fi
}
