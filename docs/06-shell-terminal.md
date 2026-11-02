# Shell and terminal

## Login shell

`/bin/zsh`.

## fish

`~/.config/fish/config.fish` (in the repo at
[`config/shell/config.fish`](../config/shell/config.fish)):

```fish
# conda initialize
eval $HOME/opt/anaconda3/bin/conda "shell.fish" "hook" $argv | source

export PATH="$PATH:$HOME/.local/bin"
```

That is the whole file. It exists mainly for the conda block and the local bin path.

## Terminals

| Terminal | Config state |
|---|---|
| Terminal.app | Default; used by the SketchyBar popups because `TERMINAL_APP="Terminal"` in `config.sh` |
| iTerm2 | `~/.config/iterm2/AppSupport` is a symlink to `~/Library/Application Support/iTerm2`; the app data is personal and not copied |
| kitty | `~/.config/kitty` exists but is empty |

If you restore on a new Mac, install the terminals you actually use. The bar only depends on
`TERMINAL_APP` for the popup "open terminal here" action.

## Other shell notes

- `PATH` already includes `/opt/homebrew/bin` and `/opt/homebrew/sbin` through the SketchyBar
  LaunchAgent environment and the login shell.
- The SketchyBar plugins invoke `/opt/homebrew/bin/python3` explicitly in several places, so a
  Homebrew Python 3 is expected.
- `~/.local/bin` is on the fish `PATH`; add it to zsh separately if needed.
