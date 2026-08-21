vim9script

if exists('s:is_loaded')
  finish
endif
var is_loaded: bool = true

#############################################################################
# logger.vim - terse, clearly-prefixed messaging for Vim9 plugins.
#
# Handles: normal messages (echom), warnings, errors, and caught exceptions.
# Prefixed as:  Plugin - script.vim - Method: message
# Script and method ommitted when not known/applicable
#
# Usage: per script:
#   import 'Logger/logger.vim' as Log
#   var log = Log.Logger.new('MyPlugin', expand('<sfile>:t'))
#
#   def DoNotPushBigRedButton()
#     log.Info('Do not press the big red button.')                 
#     log.Warn('If you press the big red button, you die, she dies, everybody
#     dies!')
#     log.Error('The idiot pressed the button.')
#     try
#       PushBigRedButton()
#     catch
#       log.Exception()
#     endtry
#   enddef
#
# Short version: (no finally/continue included)
#   def DoNotPushBigRedButton()
#     log.Try(() => PushBigRedButton())
#   enddef
#
# Messages:
#   :LoggerMessages   - opens a scratch window with recent log history
# across all Logger instances/plugins.
#   Messages emitted before VimEnter are re-shown after VimEnter, since Vim's
#############################################################################


# module shared state
var history: list<dict<any>> = []
var historyMax: number = 200
var pending: list<dict<any>> = []
var hooksInstalled: bool = false

def EnsureHooks(): void
  if hooksInstalled
    return
  endif
  hooksInstalled = true
  augroup LoggerFlushPending
    autocmd!
    autocmd VimEnter * FlushPending()
  augroup END
enddef

def EchoMsg(kind: string, text: string)
  if kind ==# 'error' || kind ==# 'exception'
    echohl ErrorMsg
  elseif kind ==# 'warn'
    echohl WarningMsg
  endif
  echom text
  echohl None
enddef

def Record(kind: string, text: string)
  history->add({kind: kind, text: text, time: strftime('%H:%M:%S')})
  if len(history) > historyMax
    history->remove(0)
  endif

  var entered: bool = !exists('v:vim_did_enter') || v:vim_did_enter
  if !entered
    pending->add({kind: kind, text: text})
  endif
enddef

def FlushPending()
  if empty(pending)
    return
  endif
  for item in pending
    EchoMsg(item.kind, item.text)
  endfor
  pending = []
enddef

def ShowHistory(): void
  if empty(history)
    echom 'Logger: no messages recorded yet.'
    return
  endif
  new
  setlocal buftype=nofile bufhidden=wipe noswapfile nobuflisted
  setlocal filetype=log
  setline(1, history->mapnew((_, h) => printf('[%s] %s', h.time, h.text)))
  setlocal nomodifiable
enddef

command! -bar LoggerMessages ShowHistory()


#######################################################################
# Class: Logger
#######################################################################
export class Logger
  var plugin: string
  var script = ''
  var level = 2               # -1=silent 0=error 1=warn 2=info(default)

  def new(this.plugin = v:none, this.script = v:none, this.level = v:none)
    EnsureHooks()
  enddef

  # Builds "Plugin - script - method: " (omitting parts that are unset).
  def Prefix(method: string): string
    var parts: list<string> = [this.plugin]
    if this.script != ''
      parts->add(this.script)
    endif
    var text = parts->join(' - ')
    if method != ''
      text ..= ' - ' .. method
    endif
    return text .. ': '
  enddef

  # Best-effort caller-function detection via the (Vim 9-only) full call
  # stack. Gracefully returns '' if unavailable/unparseable
  def CallerName(skip = 2): string
    try
      var stack = expand('<stack>')
      if stack ==# '' || stack ==# '<stack>'
        return ''
      endif
      var frames = stack->split('\.\.')
      var idx = len(frames) - 1 - skip
      if idx < 0 || idx >= len(frames)
        return ''
      endif
      var name = substitute(frames[idx], '\[\d\+\]$', '', '')
      name = substitute(name, '^.*[/\\]', '', '')
      if name ==# '' || name =~# '\.vim$'
        return ''          # top-level script code, not inside a function
      endif
      return name
    catch
      return ''
    endtry
  enddef

  # echom
  def Info(msg: string, method = '')
    if this.level < 2
      return
    endif
    var m = method != '' ? method : this.CallerName()
    var text = this.Prefix(m) .. msg
    Record('info', text)
    EchoMsg('info', text)
  enddef

  def Warn(msg: string, method = '')
    if this.level < 1
      return
    endif
    var m = method != '' ? method : this.CallerName()
    var text = this.Prefix(m) .. '[WARN] ' .. msg
    Record('warn', text)
    EchoMsg('warn', text)
  enddef

  def Error(msg: string, method = '')
    if this.level < 0
      return
    endif
    var m = method != '' ? method : this.CallerName()
    var text = this.Prefix(m) .. '[ERROR] ' .. msg
    Record('error', text)
    EchoMsg('error', text)
  enddef

  # Call with no args from inside a catch block to log v:exception /
  # v:throwpoint automatically, or pass your own text explicitly.
  def Exception(exception = v:exception, throwpoint = v:throwpoint, method = '')
    if this.level < 0
      return
    endif
    var text: string
    if exception =~# '\[EXCEPTION\] '
      text = exception
    else
      var m = method != '' ? method : this.CallerName()
      text = this.Prefix(m) .. '[EXCEPTION] ' .. exception
    endif
    Record('exception', text)
    EchoMsg('exception', text)
    if throwpoint != ''
      echom '  at ' .. throwpoint
    endif
  enddef


  # Use with a bare `throw log.Fmt('message')
 def Fmt(msg: string, method = ''): string
    var m = method != '' ? method : this.CallerName()
    var text = this.Prefix(m) .. '[EXCEPTION] ' .. msg
    Record('exception', text)
    return text
  enddef


  # Wrap a zero-arg Funcref in try/catch, auto-logging any exception.
  # Returns the Funcref's result, or v:none if it threw.
  def Try(Fn: func(): any, method = ''): any
    var m = method != '' ? method : this.CallerName()
    try
      return Fn()
    catch
      this.Exception(v:exception, v:throwpoint, m)
      return v:none
    endtry
  enddef
endclass
