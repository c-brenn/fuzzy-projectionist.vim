# Fuzzy Projectionist

Project navigation and fuzzy finders combined!

Use projections and FZF together to navigate projects with ease.

Supports Vim >= `7.4.2044` and Neovim (requires `echo has('lambda')`).

## Features

Integrates with [vim-projectionist][] and [fzf][] to allow you to narrow the
list of files to fuzzy search.

[vim-projectionist][] exposes commands (`:Etype`, `:Vtype`, `:Stype` ...) for
quick project navigation and [fzf][] is a speedy fuzzy finder. This plugin
combines the two, exposing one command for each type of file in your project.
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

Hit enter to dive into FZF for that type.

When you're in FZF, use `enter` to open the file in the current buffer, `ctrl-x` to open in a new
split, `ctrl-v` for a vertical split or `ctrl-t` for a new tab.

There are also the following functions defined for further use:

- `fuzzy_projectionist#projection_for_type(type)`
  - fuzzy search for projections for the given type in the cws
  - eg `fuzzy_projectionist#projection_for_type('model')`
- `fuzzy_projectionist#choose_projection()`
  - choose which type of file to project

[vim-projectionist]: https://github.com/tpope/vim-projectionist
[fzf]:               https://github.com/junegunn/fzf
