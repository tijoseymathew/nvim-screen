#!/usr/bin/env bash
# Bash completion for nvim-screen

_nvim_screen_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Get session directory
    local session_dir="${XDG_RUNTIME_DIR:-/tmp}/nvim-sessions-${USER}"
    local socket_prefix="nvim-session"

    # Main options
    opts="-s -S -ls -list -r -x -d -D -wipe -v --version -h --help --"

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
        -r|-x|-d|-D)
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

            # Get remote sessions (host:session format)
            # This requires checking active SSH control sockets
            local ssh_control_prefix="ssh-control"
            if [[ -d "$session_dir" ]]; then
                for control_socket in "$session_dir"/${ssh_control_prefix}-*.sock; do
                    if [[ -S "$control_socket" ]]; then
                        local filename="${control_socket##*/}"
                        local safe_host="${filename#${ssh_control_prefix}-}"
                        safe_host="${safe_host%.sock}"

                        # Try to get remote sessions from this host
                        # We use ssh -O check to see if control master is active
                        if ssh -O check -S "$control_socket" dummy 2>&1 | grep -q "Master running"; then
                            # Get remote sessions
                            local remote_sessions
                            remote_sessions=$(ssh -S "$control_socket" dummy "
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
                                    sessions="$sessions ${safe_host}:${session}"
                                fi
                            done <<< "$remote_sessions"
                        fi
                    fi
                done
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
