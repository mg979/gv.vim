gv.vim
======

A git commit browser.

![gv](https://cloud.githubusercontent.com/assets/700826/12355378/8bbf0834-bbdf-11e5-9389-1aba7cd1fec1.png)

[gitv](https://github.com/gregsexton/gitv) is nice. But I needed a faster, and
possibly simpler alternative that I can use with a project with thousands of
commits.

Installation
------------

Requires fugitive.

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'tpope/vim-fugitive'
Plug 'junegunn/gv.vim'
```

Usage
-----

### Commands

- `:GV` to open commit browser
    - You can pass `git log` options to the command, e.g. `:GV -S foobar -- plugins`.
- `:GV!` will only list commits that affected the current file
- `:GV?` fills the location list with the revisions of the current file

`:GV` or `:GV?` can be used in visual mode to track the changes in the
selected lines.

### Mappings

- `g?` for help
- `o` or `<cr>` on a commit to display the content of it
- `o` or `<cr>` on commits to display the diff in the range
- `O` opens a new tab instead
- `gb` for `:Gbrowse`
- `Tab` to switch window
- `j` and `k` to move between commits
- `]` and `[` to browse folds in the second window
- `.` to start command-line with `:Git [CURSOR] SHA` à la fugitive
- `~` to set GitGutter diff base to the commit
- `s` to show the commit summary in a preview window
- `i` to open both summary and diff panels
- `d` (GV! only) to diff the revision in a new tab
- `yy` to copy sha to clipboard
- `q` to close

Customization
-------------

`¯\_(ツ)_/¯`
