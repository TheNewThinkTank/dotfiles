#!/usr/bin/env bash

_BREW_PREFIX="${HOMEBREW_PREFIX:-}"
if [[ -z "$_BREW_PREFIX" ]]; then
  for _BREW_BIN in "$(command -v brew || true)" /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$_BREW_BIN" ]]; then
      _BREW_PREFIX="$("$_BREW_BIN" --prefix 2>/dev/null)" || _BREW_PREFIX=""
      break
    fi
  done
fi
if [[ -n "$_BREW_PREFIX" ]]; then
  export HOMEBREW_PREFIX="$_BREW_PREFIX"
  for _TOOL_PATH in "$_BREW_PREFIX/bin" "$_BREW_PREFIX/sbin" "$_BREW_PREFIX/opt/sphinx-doc/bin" "$_BREW_PREFIX/opt/llvm/bin" "$_BREW_PREFIX/opt/ruby/bin"; do
    if [[ -d "$_TOOL_PATH" && ":$PATH:" != *":$_TOOL_PATH:"* ]]; then export PATH="$_TOOL_PATH:$PATH"; fi
  done
  if [[ -x "$_BREW_PREFIX/opt/ruby/bin/ruby" ]]; then
    _GEM_BIN="$("$_BREW_PREFIX/opt/ruby/bin/ruby" -r rubygems -e 'print Gem.bindir' 2>/dev/null)" || _GEM_BIN=""
    if [[ -d "$_GEM_BIN" && ":$PATH:" != *":$_GEM_BIN:"* ]]; then export PATH="$_GEM_BIN:$PATH"; fi
    export LDFLAGS="${LDFLAGS:--L$_BREW_PREFIX/opt/ruby/lib}"
    export CPPFLAGS="${CPPFLAGS:--I$_BREW_PREFIX/opt/ruby/include}"
  fi
fi
export LANG="${LANG:-en_US.UTF-8}"
unset _BREW_PREFIX _BREW_BIN _TOOL_PATH _GEM_BIN
