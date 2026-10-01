# Logger

Logger shows and logs the messages of Vim9 plugins. Each message names the
plugin, script, and method that sent it. Logger can also write the messages
of each plugin to its own log file.

<!-- vimdoc-ignore-start -->

[![Vim](https://img.shields.io/badge/Vim-9.1%2B-019733?logo=vim)](https://www.vim.org)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)

main:
[![Generate Vimdoc](https://github.com/Galvarcus/Logger/actions/workflows/vimdoc.yml/badge.svg?branch=main)](https://github.com/Galvarcus/Logger/actions/workflows/vimdoc.yml)
[![Tests](https://github.com/Galvarcus/Logger/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/Galvarcus/Logger/actions/workflows/tests.yml)
Development:
[![Generate Vimdoc](https://github.com/Galvarcus/Logger/actions/workflows/vimdoc.yml/badge.svg?branch=Development)](https://github.com/Galvarcus/Logger/actions/workflows/vimdoc.yml)
[![Tests](https://github.com/Galvarcus/Logger/actions/workflows/tests.yml/badge.svg?branch=Development)](https://github.com/Galvarcus/Logger/actions/workflows/tests.yml)

**Contents**

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick start](#quick-start)
- [Usage](#usage)
- [Configuration](#configuration)
- [Log files](#log-files)
- [Commands](#commands)
- [Development](#development)
- [License](#license)

<!-- vimdoc-ignore-end -->

## Requirements

Vim 9.1 or later. Logger does not load in Vim 9.0, in Neovim, or in
compatible mode.

## Installation

Install Logger together with each plugin that uses it.

With Vim packages:

```bash
git clone https://github.com/Galvarcus/Logger.git ~/.vim/pack/vendor/start/Logger
```

With vim-plug:

```vim
Plug 'Galvarcus/Logger'
```

## Quick start

Import Logger at the top of a script, and make one `Logger` for the script:

```vim
vim9script

import 'Logger/logger.vim' as Log

var log = Log.Logger.new('MyPlugin', expand('<sfile>:t'))

def Save()
  log.Info('Saved.')
enddef
```

A call to `Save()` in `foo.vim` echoes this message:

```text
MyPlugin - foo.vim - Save: Saved.
```

## Usage

### Logger objects

`Log.Logger.new({plugin}, {script}, {level})` makes a `Logger`. All
arguments are optional.

| Argument | Value |
|---|---|
| `{plugin}` | Plugin name. Options for the plugin use this name. |
| `{script}` | Script name, usually `expand('<sfile>:t')`. |
| `{level}` | Echo level for this `Logger`. Options can override it. |

Make one `Logger` in each script. All `Logger` objects with the same
plugin name use the same options and the same log file.

### Methods

| Method | Effect |
|----------------------------------------|----------------------------------|
| `Info({msg})` | Show an info message, as `:echom` does. |
| `Warn({msg})` | Show a warning with `WarningMsg` highlight. |
| `Error({msg})` | Show an error with `ErrorMsg` highlight. |
| `Exception({exception}, {throwpoint})` | Show a caught exception. The defaults are `v:exception` and `v:throwpoint`. |
| `Fmt({msg})` | Return an exception text to throw. |
| `Try({Fn})` | Call `{Fn}` and return its result. On an exception, show it and return `v:none`. |

Each method also takes an optional last argument, `{method}`. When it is
empty, Logger uses the name of the function that called it. A class method shows as `Class.Method`. Code at
script level and code in a lambda have no method name.

### Message format

An echoed message has this form:

```text
MyPlugin - foo.vim - Save: [WARN] Disk almost full.
```

Logger omits an empty plugin, script, or method name. The tags are
`[WARN]`, `[ERROR]`, and `[EXCEPTION]`. An info message has no tag. An
exception also shows its throwpoint on a second line.

### Exceptions

Catch an exception and show it:

```vim
try
  Risky()
catch
  log.Exception()
endtry
```

`Try()` does the same in one line:

```vim
var result = log.Try(() => Risky())
```

To throw where no `try` is near, use `Fmt()`:

```vim
if exists('g:this')
  Use(g:this)
elseif exists('g:that')
  Use(g:that)
else
  throw log.Fmt('Neither this nor that.')
endif
```

`Fmt()` records and logs the message when you throw it. Vim shows an
uncaught exception without Logger, so this puts it in the log file too.
When a caller catches the text and calls `Exception()`, Logger shows the
text once and does not record it again.

### Levels

| Level | Messages |
|---|---|
| `-1` | None |
| `0` | Errors and exceptions |
| `1` | Warnings, errors, and exceptions |
| `2` | All |

### Startup messages

Logger holds messages sent before `VimEnter` and echoes them after Vim
starts.[^1]

## Configuration

Each option has a global variable, `g:logger_{option}`, and a variable for
each plugin, `g:logger_{plugin}_{option}`. `{plugin}` is the plugin name in
lowercase, with each character other than a letter, digit, or underscore
changed to `_`. For the plugin `My-Plugin`, it is `my_plugin`.

Logger uses the first value it finds:

1. The plugin variable, such as `g:logger_myplugin_level`.
2. The `{level}` argument of `Logger.new()`, for `level` only.
3. The global variable, such as `g:logger_level`.
4. The default.

Logger reads the options on each message, so a change applies at once. A
value of the wrong type uses the default.

| Option | Default | Effect |
|-----------------|--------------|-------------------------------------------|
| `echo` | `true` | Echo messages. |
| `level` | `2` | Echo level. |
| `log_file` | `false` | Write messages to a log file. |
| `log_level` | `2` | Log file level. |
| `log_retention` | `10` | Number of old log files to keep for each plugin. `0` keeps all. |
| `log_dir` | `'~/.Logger'` | Log file folder. Global only. |

This example logs all plugins, keeps 20 old files for `MyPlugin`, and shows
only its errors and warnings:

```vim
g:logger_log_file = true
g:logger_myplugin_log_retention = 20
g:logger_myplugin_level = 1
```

## Log files

With `log_file` on, Logger writes the messages of each plugin to one file
for each Vim session:

```text
~/.Logger/myplugin_20260926_140311.log
```

Logger makes the folder and the file on the first message of the session.
It then deletes the oldest files of that plugin until `log_retention` old
files remain. The current file does not count.

Each message is one line. An exception adds its throwpoint on the next
line:

```text
2026-09-26 14:03:11 WARN MyPlugin - foo.vim - Save: Disk almost full.
2026-09-26 14:03:12 EXCEPTION MyPlugin - foo.vim - Load: No config file.
  at function <SNR>12_Load, line 3
```

When Logger cannot write the file, it shows one warning. That `Logger`
then stops writing to the file until Vim restarts.

## Commands

`:LoggerMessages` opens a scratch window with the last 200 messages of all
plugins.

<!-- vimdoc-ignore-start -->

## Development

Run the tests from the root of the repository:

```bash
vim -es -u NONE -N -c 'set rtp+=.' -c 'source tests/harness.vim' -c 'quit'
cat tests/results.txt
```

The `Tests` workflow runs the tests on the newest Vim and on Vim 9.1.0016.
The `Generate Vimdoc` workflow makes `doc/logger.txt` from this file on
each push to `main` and `Development`. Edit this file, not
`doc/logger.txt`. You can also start both workflows by hand.

<!-- vimdoc-ignore-end -->

## License

GNU General Public License 3.0. The full text is in `LICENSE`.

[^1]: Vim redraws the screen during startup, which hides earlier messages.
