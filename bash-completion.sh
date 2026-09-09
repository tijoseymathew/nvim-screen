#!/usr/bin/env bash
# Bash completion for nvim-screen

_nvim_screen_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Get session directory
    local user="${USER:-$(whoami)}"
    local session_dir="${XDG_RUNTIME_DIR:-/tmp}/nvim-sessions-${user}"
    local socket_prefix="nvim-session"

    # Main options
    opts="-s -S -c -ls -list -r -x -d -D -k -kill -sync -wipe -fix -v --version -h --help --"

    # Handle option-specific completions
    case "${prev}" in
        -s)
            # Complete SSH hosts from SSH config
            local ssh_hosts=""
            if [[ -f ~/.ssh/config ]]; then
                ssh_hosts=$(grep -E "^Host\s+" ~/.ssh/config | awk '{print $2}' | grep -v '\*')
            fi
            if [[ -f /etc/ssh/ssh_config ]]; then
                ssh_hosts="$ssh_hosts $(grep -E "^Host\s+" /etc/ssh/ssh_config | awk '{print $2}' | grep -v '\*')"
            fi
            COMPREPLY=( $(compgen -W "${ssh_hosts}" -- "${cur}") )
            return 0
            ;;
        -S)
            # No completion for new session names (user provides custom name)
            return 0
            ;;
        -c)
            # Complete directories; remote ones when -s <host> was given and
            # the system's ssh config already has a live control master for it
            # (so completion never opens a connection or prompts)
            local host="" i
            for ((i=1; i < COMP_CWORD; i++)); do
                if [[ "${COMP_WORDS[i]}" == "-s" ]]; then
                    host="${COMP_WORDS[i+1]:-}"
                fi
            done
            if [[ -n "$host" ]]; then
                if ssh -O check "$host" 2>&1 | grep -q "Master running"; then
                    local remote_dirs
                    remote_dirs=$(ssh -o BatchMode=yes "$host" \
                        "bash -c 'compgen -d -S / -- \"$cur\"'" 2>/dev/null)
                    COMPREPLY=( $(compgen -W "$remote_dirs" -- "$cur") )
                fi
            else
                COMPREPLY=( $(compgen -d -S / -- "$cur") )
            fi
            compopt -o nospace 2>/dev/null
            return 0
            ;;
        -r|-x|-d|-D|-k|-kill)
            # Complete with active session names
            local sessions=""

            # Get local sessions
            if [[ -d "$session_dir" ]]; then
                for socket in "$session_dir"/${socket_prefix}-*.sock; do
                    if [[ -S "$socket" ]]; then
                        local name="${socket##*/}"
                        name="${name#${socket_prefix}-}"
                        name="${name%.sock}"
                        sessions="$sessions $name"
                    fi
                done
            fi

            # Get remote sessions (host:session format) from the hosts
            # nvim-screen has connected to. Only hosts whose ssh control
            # master is already live are asked: completion has to be instant
            # and must never open a connection or prompt for a password.
            local hosts_file="$session_dir/ssh-hosts"
            if [[ -r "$hosts_file" ]]; then
                local remote_host
                while IFS= read -r remote_host; do
                    [[ -n "$remote_host" ]] || continue
                    ssh -O check "$remote_host" 2>&1 | grep -q "Master running" || continue

                    local remote_sessions
                    remote_sessions=$(ssh -o BatchMode=yes "$remote_host" "
                        for socket in \"\${XDG_RUNTIME_DIR:-/tmp}/nvim-sessions-\$USER\"/nvim-session-*.sock; do
                            if [[ -S \"\$socket\" ]]; then
                                name=\"\${socket##*/}\"
                                name=\"\${name#nvim-session-}\"
                                name=\"\${name%.sock}\"
                                echo \"\$name\"
                            fi
                        done
                    " 2>/dev/null)

                    # Add remote sessions with host: prefix
                    while IFS= read -r session; do
                        if [[ -n "$session" ]]; then
                            sessions="$sessions ${remote_host}:${session}"
                        fi
                    done <<< "$remote_sessions"
                done < "$hosts_file"
            fi

            COMPREPLY=( $(compgen -W "${sessions}" -- "${cur}") )
            return 0
            ;;
    esac

    # Check if we're after the -- separator
    for ((i=0; i < COMP_CWORD; i++)); do
        if [[ "${COMP_WORDS[i]}" == "--" ]]; then
            # After --, we're completing nvim arguments
            # We could add file completion here
            COMPREPLY=( $(compgen -f -- "${cur}") )
            return 0
        fi
    done

    # Default: complete with available options
    COMPREPLY=( $(compgen -W "${opts}" -- "${cur}") )
    return 0
}

# Register the completion function
complete -F _nvim_screen_completions nvim-screen
