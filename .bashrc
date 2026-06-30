#!/usr/bin/env bash

# If not running interactively, don't do anything
[[ -n $PS1 ]] || return

# Shared configuration
. ~/.shrc

# History configuration
HISTCONTROL=ignoreboth
HISTTIMEFORMAT="%Y-%m-%d %T "

# Shell Options
shopt -s cdspell
shopt -s checkwinsize
shopt -s extglob

# Bash Version >= 4
shopt -s autocd   2>/dev/null || true
shopt -s dirspell 2>/dev/null || true

make-prompt() {
        local rst=$'\e[0m'
        local bold=$'\e[1m'
        local col1=$'\e[38;5;24m'
        local col2=$'\e[38;5;54m'
        local col3=$'\e[38;5;114m'
        local col4=$'\e[38;5;84m'

        PS1='\['$col1'\]gus\['$rst'\]'
        PS1+='\['$bold'\]\['$col2'\]@\['$rst'\]'
        PS1+='\['$col3'\]\h '
        PS1+='\['$col4'\]\$\['$rst'\] '
}
make-prompt

_prompt_command() {
        local user=$USER
        local host=${HOSTNAME%%.*}
        local pwd=${PWD/#$HOME/\~}
        local ssh=
        [[ -n $SSH_CLIENT ]] && ssh='[ssh] '
        printf "\033]0;%s%s@%s:%s\007" "$ssh" "$user" "$host" "$pwd"
}
PROMPT_COMMAND=_prompt_command


# Generated for envman. Do not edit.
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

# load completion
. /etc/bash/bash_completion 2>/dev/null ||
        . ~/.bash_completion 2>/dev/null

true
