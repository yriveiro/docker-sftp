#!/bin/bash

set -xeuo pipefail

cmd="$1"
user_data=${USER_DATA_PATH:-/srv}

function running_as_root
{
    test "$(id -u)" = "0"
}

function __user
{
    if [ -z "$USER" ]; then
        echo >&2 'USER variable not set'
        exit 1
    fi
}

function __password
{
    if [ -z "$PASSWORD" ]; then
        echo >&2 'PASSWORD variable not set'
        exit 1
    fi
}

function create_user
{
    addgroup "${1}"
    adduser -D -h "${user_data}${1}" -G "${1}" "${1}"
    echo "${1}:${2}" | chpasswd
}

function generate_ssh_keys
{
    # Generate unique ssh keys for this container, if needed
    if [ ! -f /etc/ssh/ssh_host_ed25519_key ]; then
        ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ''
    fi

    if [ ! -f /etc/ssh/ssh_host_rsa_key ]; then
        ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N ''
    fi
}
__user
__password
create_user "${USER}" "${PASSWORD}"
generate_ssh_keys

if running_as_root; then
    userid="${USER}"
    groupid="${USER}"
    groups=($(id -G "${USER}"))
else
    userid="$(id -u)"
    groupid="$(id -g)"
    groups=($(id -G))
fi

readonly userid
readonly groupid
readonly groups

# Need to chown the home directory - but a user might have mounted a
# volume here (notably a conf volume). So take care not to chown
# volumes (stuff not owned by gfs)

if running_as_root; then
    # Non-recursive chown for the base directory
    chown root:"${groupid}" "${user_data}${USER}"
    chmod 555 ${user_data}"${USER}"

    mkdir -p ${user_data}"${USER}"/data
    chmod 777 ${user_data}"${USER}"/data
    find ${user_data}"${USER}"/data -mindepth 1 -maxdepth 1 -type d -exec chown -R ${userid}:${groupid} {} \;
    find ${user_data}"${USER}"/data -mindepth 1 -maxdepth 1 -type d -exec chmod -R 777 {} \;
fi

if [ "${cmd}" == "loop" ]; then
    exec gosu "${USER}":"${USER}" tail -f /dev/null
elif [ "${cmd}" == "start" ]; then
    exec gosu root:root /usr/sbin/sshd -D -e
else
    exec gosu "${USER}":"${USER}" $@
fi
