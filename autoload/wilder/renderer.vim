function! wilder#renderer#redraw(apply_incsearch_fix) abort
  call s:redraw(a:apply_incsearch_fix, 0)
endfunction

function! wilder#renderer#redrawstatus(apply_incsearch_fix) abort
  call s:redraw(a:apply_incsearch_fix, 1)
endfunction

function! s:redraw(apply_incsearch_fix, is_redrawstatus) abort
  if a:apply_incsearch_fix &&
        \ &incsearch &&
        \ (getcmdtype() ==# '/' || getcmdtype() ==# '?')
    call feedkeys("\<C-R>\<BS>", 'n')
    return
  endif

  if a:is_redrawstatus
    redrawstatus
  else
    redraw
  endif
endfunction

function! wilder#renderer#get_cmdheight() abort
  if !has('nvim')
    " For Vim, if cmdline exceeds cmdheight, the screen lines are pushed up
    " similar to :mess, so we draw the popupmenu just above the cmdline.
    " Lines exceeding cmdheight do not count into target line number.
    return &cmdheight
  endif

  let l:cmdline = getcmdline()

  " include the cmdline character
  let l:display_width = strdisplaywidth(l:cmdline) + 1
  let l:cmdheight = l:display_width / &columns + 1

  if l:cmdheight < &cmdheight
    let l:cmdheight = &cmdheight
  elseif l:cmdheight > 1
    " Show the pum above the msgsep.
    let l:has_msgsep = stridx(&display, 'msgsep') >= 0

    if l:has_msgsep
      let l:cmdheight += 1
    endif
  endif

  return l:cmdheight
endfunction
