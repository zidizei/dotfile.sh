#!/bin/bash
# **[dotfile.sh](https://github.com/zidizei/dotfile.sh/)** is a shell script to install
# (symlink) various collections of dotfiles onto your system.

#/
#/ Usage: dotfile.sh [<options>] [<dotfile...>]
#/
#/ The <dotfile...> is a space-separated list of dotfile collections that should be installed.
#/ If left out, all the dotfiles that can be found will be installed.
#/ Collections are found inside folders of the same name under your current working directory.
#/
#/ Options:
#/   -d,--debug          Passing the debug option will set the -x flag for bash.
#/   --preview           Don't actually install any dotfiles.
#/                       Pre/post hooks and backup creations are not going to be run as well.
#/   --linux             Explicitly install any dotfiles for Linux.
#/   --osx               Explicitly install any dotfiles for macOS.

# Refer to the [README](https://github.com/zidizei/dotfile.sh/blob/master/README.md) for more
# information about the usage and installation of **dotfile.sh**.
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

    # If the file or folder in question already exists, we'll check whether a backup of it
    # already exists, as well.
    #
    # If that's the case, the user can decide between two options on how to proceed.
    # The first option is to not create a new backup. This means that the existing file or folder
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

# ## Collections
#
# The collections that are to be installed come from the command-line arguments.
# If none are specified, we'll install all the dotfiles we can find.
# Otherwise, the script checks if we can find a directory with the same name for each
# specified collection.
COLLECTIONS=()
if [[ "$TARGETS" == "" ]]; then
    COLLECTIONS=$(ls -1d */)
else
for t in $TARGETS; do
    [ -d "$t" ] && COLLECTIONS="$COLLECTIONS $t"
done
fi

# For each found collection, **dotfile.sh** will determine the way its dotfiles should
# be installed (see above). The most straight-forward check is to see, if an `INSTALL.sh`
# file can be found.
for t in $COLLECTIONS; do
    echo -ne "Installing \033[1;32m$t $(tput sgr0)..."

    # If an `INSTALL.sh` file is available, we'll load it into a sub-shell, so we can call its
    # `pre` and `post` hook functions, if they have been defined. Whether the dotfile collection
    # should be bundled is determined by the `INSTALL.sh`'s `$TARGET` variable. If it is set,
    # the collection will be installed as a bundle at the location specified by that variable.
    #
    # > **TODO:** Use another extra variable to determine the installation method, since there might
    # > be cases where someone would want to symlink individual dotfiles at a custom location.
    # > Right now, this only works for dotfiles and folders being symlinked to `$HOME`.
    #
    # If it is not set, the dotfiles are installed using individual symbolic links.
    if [ -f "$t/INSTALL.sh" ]; then
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

    # This is also the installation method when a collection does not contain an `INSTALL.sh` file.
    # The dotfiles and folders are symlinked to the user's home directory.
    else
        echo
        linkDotfiles "$t"
    fi
    tput sgr0
    echo
done

# After all the collections have been iterated through (if there were any), we say goodbye and we're done. 👌
if [ ${#COLLECTIONS[@]} -gt 0 ]; then
    echo -e 'Installation Finished \033[0;32m✓\033[0m'
else
    echo 'No dotfiles to install ...'
    echo 'Make sure you specified the right directory names for your dotfiles.'
fi
