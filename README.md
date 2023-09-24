# cmp-omni

[nvim-cmp](https://github.com/hrsh7th/nvim-cmp) source for [Vimtex](https://github.com/lervag/vimtex)'s omnifunc.
Based on [@hrsh7th](https://github.com/hrsh7th)'s [cmp-omni](https://github.com/hrsh7th/cmp-omni), with help from [@lervag](https://github.com/lervag).

# Setup

```lua
require'cmp'.setup {
  sources = {
    {
      name = 'omni',
      option = {
        info_in_menu = 1,
        info_in_window = 1,
        match_against_description = 1,
        symbols_in_menu = 1,
      },
    },
  },
}
```

# Option

### info_in_menu: integer
default: 1

Show detailed information (such as citations details) in the completion menu.

### info_in_window: integer
default: 1

Show detailed information (such as citations details) in the documentation window.

### match_against_description: integer
default: 1

Fuzzy match against both keyword and description.
Particularly useful when completing citations, since the user can simply type the author/title/publication date.

### symbols_in_menu: integer
default: 1

Show sybmols associated with Latex keywords inside completion menu.
