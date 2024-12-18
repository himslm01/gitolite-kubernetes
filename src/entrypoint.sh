#!/bin/sh

set -e

error=false

if test -z "${GIT_UID}" ; then
    echo "environment variable GIT_UID must be set"
    echo "1000 is a usual value"
    error=true
fi

if test -z "${GIT_GID}" ; then
    echo "environment variable GIT_GID must be set"
    echo "1000 is a usual value"
    error=true
fi

if test true = $error; then
    exit 1
fi

addgroup -g ${GIT_GID} -S git
adduser -u ${GIT_UID} -G git -D git

chown git:git /home/git
chmod 0750 /home/git
chown git:git /repositories
chmod 0766 /repositories

# test if we think Gitolite has been setup

if ! test -f /home/git/projects.list; then
    echo "Setting up new Gitolite environment"

    if test -z "${GITOLITE_ADMIN_PUBKEY}" ; then
        echo "environment variable GITOLITE_ADMIN_PUBKEY must be set"
        error=true
    fi

    if test -z "${GITOLITE_ADMIN_USERNAME}" ; then
        echo "environment variable GITOLITE_ADMIN_USERNAME must be set"
        error=true
    fi

    repo_count=$(ls /repositories/ | wc -l)

    if ! test 0 = $repo_count; then
        echo "files or directories exist in the folder /repositories"
        error=true
    fi

    if test -d /home/git/repositories; then
        echo "the folder /home/git/repositories exists"
        error=true
    fi

    if test -L /home/git/repositories; then
        echo "the symbolic link /home/git/repositories exists"
        error=true
    fi

    if test -f /home/git/repositories; then
        echo "a file at /home/git/repositories exists"
        error=true
    fi

    if test true = $error; then
        echo "cannot setup Gitolite"
        exit 1
    fi

    echo "${GITOLITE_ADMIN_PUBKEY}" > "/home/git/${GITOLITE_ADMIN_USERNAME}.pub"
    chown git:git "/home/git/${GITOLITE_ADMIN_USERNAME}.pub"
    gosu git:git git config --global init.defaultBranch main
    gosu git:git gitolite setup -pk "${GITOLITE_ADMIN_USERNAME}.pub"
    mv -v /home/git/repositories/* /repositories/
    rmdir /home/git/repositories
    ln -s /repositories /home/git/repositories
fi

exec gosu git:git "$@"
