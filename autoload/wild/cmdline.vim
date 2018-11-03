func wild#cmdline#parse(cmdline) abort
  if exists('s:cache_cmdline') && a:cmdline ==# s:cache_cmdline
    return s:cache
  else
    let l:ctx = {'cmdline': a:cmdline, 'pos': 0, 'cmd': ''}
    call wild#cmdline#main#do(l:ctx)

    let s:cache = l:ctx
    let s:cache_cmdline = a:cmdline
  endif

  return copy(l:ctx)
endfunc

function! wild#cmdline#has_file_args(cmd)
  return wild#cmdline#main#has_file_args(a:cmd)
endfunction

function! wild#cmdline#is_user_command(cmd)
  return !empty(a:cmd) && a:cmd[0] >=# 'A' && a:cmd[0] <=# 'Z'
endfunction

function! wild#cmdline#get_user_completion(cmdline)
  let l:ctx = wild#cmdline#parse(a:cmdline)

  let l:user_commands = nvim_get_commands({})

  if !has_key(l:user_commands, l:ctx.cmd)
    return v:false
  endif

  let l:user_command = l:user_commands[l:ctx.cmd]

  if has_key(l:user_command, 'complete') &&
        \ l:user_command.complete !=# 'custom' && l:user_command.complete !=# 'customlist'
    let l:completions = cmdline(l:ctx.cmdline[l:ctx.pos :], l:user_command.complete)

    if l:user_command.complete ==# 'file' ||
          \ l:user_command.complete ==# 'file_in_path' ||
          \ l:user_command.complete ==# 'dir'
      return map(l:completions, {_, x -> escape(x, ' ')})
    endif

    return l:completions
  endif

  if !has_key(l:user_command, 'complete_arg') || l:user_command.complete_arg is v:null
    return v:false
  endif

  let l:Completion_func = function(l:user_command.complete_arg)

  " pos + 1 for the command prompt
  return l:Completion_func(l:ctx.cmdline[l:ctx.pos :], l:ctx.cmdline, l:ctx.pos + 1)
endfunction

func wild#cmdline#replace(ctx, cmdline, x) abort
  let l:result = wild#cmdline#parse(a:cmdline)

  if l:result.pos == 0
    return a:x
  endif

  if match(l:result.cmd, 'menu$') != -1
    return l:result.cmdline[: l:result.pos - 1] . a:x
  endif

  return l:result.cmdline[: l:result.pos - 1] . a:x
endfunction

function! wild#cmdline#pipeline(opts) abort
  return [
      \ wild#check({-> getcmdtype() ==# ':'}),
      \ {_, x -> wild#cmdline#parse(x)},
      \ wild#branch(
      \   [
      \     wild#check({_, res -> wild#cmdline#is_user_command(res.cmd)}),
      \     {_, res -> wild#cmdline#get_user_completion(res.cmdline)},
      \   ],
      \   [
      \     wild#check({_, res -> wild#cmdline#has_file_args(res.cmd)}),
      \     {_, res -> map(getcompletion(res.cmdline, 'cmdline'), {_, x -> escape(x, ' ')})},
      \   ],
      \   [
      \     {_, res -> getcompletion(res.cmdline, 'cmdline')},
      \   ],
      \ ),
      \ {_, xs -> map(xs, {_, x -> {'result': x, 'replace': 'wild#cmdline#replace'}})},
      \ ]
endfunction

let s:substitute_commands = {
      \ 'substitute': v:true,
      \ 'smagic': v:true,
      \ 'snomagic': v:true,
      \ 'global': v:true,
      \ 'vglobal': v:true,
      \ '&': v:true,
      \ }

function! wild#cmdline#is_substitute_command(cmd)
  return has_key(s:substitute_commands, a:cmd)
endfunction

function! wild#cmdline#substitute_pipeline(opts) abort
  let l:pipeline = get(a:opts, 'pipeline', [
        \ wild#vim_substring(),
        \ wild#vim_search(),
        \ ])

  let l:hide = get(a:opts, 'hide', 1)

  return [
      \ wild#check({-> getcmdtype() ==# ':'}),
      \ {_, x -> wild#cmdline#parse(x)},
      \ wild#check({_, res -> wild#cmdline#is_substitute_command(res.cmd)}),
      \ {_, res -> wild#cmdline#substitute#parse({'cmdline': res.cmdline[res.pos :], 'pos': 0})},
      \ {_, res -> len(res) == 2 ? res : (l:hide ? v:true : v:false)},
      \ wild#map(
      \   [{_, vs -> vs[0]}],
      \   [{_, vs -> vs[1]}] + l:pipeline,
      \ ),
      \ {_, vs -> map(vs[1], {_, x -> {'result': x,
      \   'draw': escape(x, '^$.*~[]\'),
      \   'output': vs[0] . x,
      \   'replace': 'wild#cmdline#replace'
      \ }})},
      \ ]
endfunction