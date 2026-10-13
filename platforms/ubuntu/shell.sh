#!/usr/bin/env bash

[[ ":$PATH:" == *":$HOME/.local/bin:"* ]] || export PATH="$HOME/.local/bin:$PATH"
export LANG="${LANG:-C.UTF-8}"
