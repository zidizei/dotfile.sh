#!/bin/bash
# **dotfile.sh** is a shell script to install (symlink) various collections of dotfiles onto your system.

#/
#/ Usage: dotfile.sh [<options>] <dotfile...>
#/
#/ The <dotfile...> is a space-separated list of dotfile collections that should be installed.
#/ Collections are found inside folders of the same name under your current working directory.
#/
#/ Options:
#/   -d,--debug          Passing the debug option will set the -x flag for bash.
#/   --preview           Don't actually install any dotfiles.
#/                       Pre/post hooks and backup creations are not going to be run as well.
#/   --linux             Explicitly install any dotfiles for Linux.
#/   --osx               Explicitly install any dotfiles for macOS.
set -eo pipefail

PLATFORM=()
TARGETS=()
POSITIONAL=()
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -d|--debug)
        set -x
        shift # past argument
        ;;
        --preview)
        PREVIEW=1
        shift # past argument
        ;;
        -p|--platform)
        PLATFORM="$2"
        shift # past argument
        shift # past value
        ;;
        --linux)
        PLATFORM="linux"
        shift
        ;;
        --osx)
        PLATFORM="osx"
        shift
        ;;
        *)
        TARGETS="$TARGETS $key"
        shift
        ;;
    esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

[ -z ${PLATFORM+x} ] && PLATFORM=$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo none)

# **dotfiles** works by grouping up your various dotfiles (or any other configuration files, really) in
# folders, that are referred to as **collections**. For example, a collection for Vim configuration files
# could look like the following:
#├── vimfiles/
#│   ├── vim/
#│   ├── INSTALL.sh
#│   └── vimrc
# By running `dotfiles vimfiles`, the `vimrc` file would be symlinked to `$HOME/.vimrc`
# and the `vim` folder, which might contain all your plugins for Vim, will be symlinked to `$HOME/.vim`.
#
# Some collections might require some additional installation steps. These can be specified inside a
# `INSTALL.sh` file, where a `pre()` and/or `post()` function can defined. These hooks will then be called
# before and after the installation of the collection's dotfiles, respectively.
#
# It is also possible to tell **dotfile.sh** where the files and folders should be installed to
# by setting the `$TARGET` variable, which defaults to `$HOME`.
#
# In case there's already a dotfile or folder present, a backup is created.
#
# ## Backing up existing dotfiles
#
# Backups are created by appending ".backup" the original file's name.
function backupExistingDotfiles {
    createBackup() {
        echo -e "\033[0;31mCreating backup of existing dotfiles at $1.backup\033[0m"
        mv $1 $1.backup
    }

    # If the file or folder in question already exists, we'll check if maybe a backup
    # already exists, too.
    #
    # If that's the case, the user can decide between two options on how to proceed.
    # The first option is to not create a new backup. In this case, the existing file or folder
    # will be **removed** and no new backup is created.
    #
    # The second option is to remove the existing backup instead, so a new
    # one can be created.
    if [ -f $1 ] || [ -d $1 ]; then
        if [ -f "$1.backup" ] || [ -d "$1.backup" ]; then
            echo
            echo -e "\033[0;33mExisting backup of dotfiles found at $1.backup\033[0m"
            select yn in "Do not create a new backup." "Override old backup with a new one."; do
                case $yn in
                    "Do not create a new backup.")
                    rm -rf $1
                    echo -e "\033[0;31mRemoving dotfiles at $1 without creating backups!\033[0m"
                    return 0
                    ;;
                    "Override old backup with a new one.")
                    rm -rf $1.backup
                    break
                    ;;
                esac
            done
        fi

        createBackup "$1"
    fi
    return 0
}

# After creating the necessary backups of files and folders, the new dotfiles can be installed.
# There are two ways this can happen.
#
# ## Symlinking individual dotfiles
#
# The simplest way is to symlink the individual files and folders. This is also what was shown previously
# with the `vimfiles` example.
function linkDotfiles {
    for f in $(ls -1 $1); do
        # In order to install dotfiles this way, we will iterate through every file and folder found
        # inside a collection and create backups of their original versions on the machine, if necessary.
        [ -z ${PREVIEW+x} ] && backupExistingDotfiles "$HOME/.$f"
        if [ "$f" != "INSTALL.sh" ]; then
            # Then, everything (except the collection specific installation script in `INSTALL.sh`) will be symlinked
            # to the user's home directory.
            echo -e "Linking \033[1;34m$f\033[0m to \033[1;34m$HOME/.$f\033[0m"
            [ "$PREVIEW" ] || ln -s "$(pwd -P)/$1/$f" $HOME/.$f
        fi
    done
}

# ## Symlinking a bundle of dotfiles
#
# The other way is to symlink to whole collection's folder to a specific target path.
# This is referred to as a **bundle** of dotfiles. Where exactly the folder
# should be symlinked to is specified by the `$TARGET` variable, which should be
# defined in the `INSTALL.sh` file.
function bundleDotfiles {
    [ "$PREVIEW" ] || backupExistingDotfiles "$2"
    echo -e "Bundling \033[1;34m$1\033[0m at \033[1;34m$2\033[0m"
    [ "$PREVIEW" ] || ln -s "$(pwd -P)/$1" $2
}

#
for t in $TARGETS; do
    echo -ne "Installing \033[1;32m$t $(tput sgr0)..."

    if [ -d "$t" ] && [ -f "$t/INSTALL.sh" ]; then
        (
            source "$t/INSTALL.sh"
            echo
            if type pre &>/dev/null; then
                (
                    echo -e "\033[0m\033[2mExecuting Pre-Install Hook\033[0m"
                    pre
                    echo -e "\033[0m\033[2mDone ✓\033[0m"
                ) | sed "s,.*,$(tput setaf 8)[pre]$(tput sgr0) &,"
            fi
            if [ -z ${TARGET+x} ]; then
                linkDotfiles "$t"
            else
                bundleDotfiles "$t" "$TARGET"
            fi
            if type post &>/dev/null; then
                (
                    echo -e "\033[0m\033[2mExecuting Post-Install Hook\033[0m"
                    post
                    echo -e "\033[0m\033[2mDone ✓\033[0m"
                ) | sed "s,.*,$(tput setaf 8)[post]$(tput sgr0) &,"
            fi
        )
    elif [ -d "$t" ]; then
        echo
        linkDotfiles "$t"
    fi
    tput sgr0
    echo
done

echo -e 'Installation Finished \033[0;32m✓\033[0m'
