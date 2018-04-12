# dotfile.sh

Installation script to install and manage your dotfiles (or any other configuration files, really).

```
Usage: dotfile.sh [<options>] [<dotfile...>]

The <dotfile...> is a space-separated list of dotfile collections that should be installed.
If left out, all the dotfiles that can be found will be installed.
Collections are found inside folders of the same name under your current working directory.

Options:
  -d,--debug          Passing the debug option will set the -x flag for bash.
  --preview           Don't actually install any dotfiles.
                      Pre/post hooks and backup creations are not going to be run as well.
  --linux             Explicitly install any dotfiles for Linux.
  --osx               Explicitly install any dotfiles for macOS.
```

The **dotfiles** command works by grouping up your various dotfiles (or any other configuration files, really) in
folders, that are referred to as **collections**. For example, a collection for Vim configuration files
could look like the following:

```
├── vimfiles/
│   ├── vim/
│   ├── INSTALL.sh
│   └── vimrc
```

By running `dotfiles vimfiles`, the `vimrc` file would be symlinked to `$HOME/.vimrc`
and the `vim` folder, which might contain all your plugins for Vim, will be symlinked to `$HOME/.vim`.

Some collections might require some additional installation steps. These can be defined inside a
`INSTALL.sh` file, where a `pre()` and/or `post()` function can defined. These hooks will then be called
before and after the installation of the collection's dotfiles, respectively.

In case there's already a `.vimrc` file or `vim` folder present, a backup is created.
