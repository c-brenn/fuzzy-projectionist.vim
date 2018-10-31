# Fuzzy Projectionist

[![Build 
Status](https://travis-ci.com/cormacrelf/fuzzy-projectionist.vim.svg?branch=master)](https://travis-ci.com/cormacrelf/fuzzy-projectionist.vim)

Project navigation and fuzzy finders combined!

Use projections and FZF together to navigate projects with ease.

Supports Vim >= `7.4.2044` and Neovim (requires `echo has('lambda')`).

## Features

Integrates with [vim-projectionist][] and [fzf][] to allow you to narrow the
list of files to fuzzy search.

[vim-projectionist][] exposes commands (`:Etype`, `:Vtype`, `:Stype` ...) for
quick project navigation and [fzf][] is a speedy fuzzy finder. This plugin combines the two, exposing one command for each type of file in your project.
You can use FZF's key bindings to open the file in a new buffer/split/tab
instead of having to map each of the different projectionist commands.

## Examples

With this minimal configuration for a Rails project:

```json
{
  "app/models/*.rb": {
    "type": "model"
  },
  "app/controllers/*.rb": {
    "type": "controller"
  },
  "app/views/*.rb": {
    "type": "view"
  }
}
```

You can now use FZF when projecting around the project with the commands:

- `:Fmodel`
- `:Fcontroller`
- `:Fview`

Hit enter to dive into FZF for that type. Each F command takes an optional
argument that pre-populates the search query, and jumps directly to a file
if there is only one match. As with all commands, you can abbreviate where
possible, like `:Fc hom` to get to your home controller.

When you're in FZF, use `enter` to open the file in the current buffer, `ctrl-x` to open in a new
split, `ctrl-v` for a vertical split or `ctrl-t` for a new tab.

There are also the following functions defined for further use:

- `fuzzy_projectionist#projection_for_type(type)`
  - fuzzy search for projections for the given type in the cws
  - eg `fuzzy_projectionist#projection_for_type('model')`
- `fuzzy_projectionist#choose_projection()`
  - choose which type of file to project

You can also enable a little preview window with `let g:fuzzy_projectionist_preview = 1`.

### Note on depth

`vim-projectionist` lists matches from parent directories that were found in 
your `g:projectionist_heuristics`. Say you had:

```
let g:projectionist_heuristics = {"Makefile": { "src/*.c": {"type": "source"} } 
.
├── Makefile
├── midlevel
│   ├── Makefile
│   ├── lower
│   │   ├── Makefile
│   │   └── src
│   │       └── low.c
│   └── src
│       └── mid.c
└── src
    └── root.c
```

... and you were in the `lower/` directory.

`:Esource` and `Fsource` will both give you `root`, `mid`, `low`

This makes sense if there is no crossover between the pre-glob projection path 
and the subdirectories (i.e. `midlevel` is not inside `src/`, it is adjacent). 
If this isn't the case for you and you have something like

```
heuristics: { "Makefile": {"*.c": {"type": "source"} } }
.
├── Makefile
├── midlevel
│   ├── Makefile
│   ├── lower
│   │   ├── Makefile
│   │   └── low.c
│   └── mid.c
└── root.c
```

...producing `root midlevel/lower/low midlevel/mid mid lower/low low`, then you 
can set `let g:fuzzy_projectionist_depth = 1` to only look the 1 level nearest 
to your current file. From `lower`, that would be `low`; from the root, that 
would be `root mid low`. This only applies to `Fsource`. The default is 0 
(infinite). 

## Testing

There is a comprehensive test suite written in [vader][]. Run `./test/run.sh 
--help` for more info.

[vim-projectionist]: https://github.com/tpope/vim-projectionist
[fzf]:               https://github.com/junegunn/fzf
[vader]:             https://github.com/junegunn/vader.vim


