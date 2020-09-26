" presenting.vim - presentation for vim

au FileType markdown let b:presenting_slide_separator_default = '\v(^|\n)\ze#+'
au FileType mkd      let b:presenting_slide_separator_default = '\v(^|\n)\ze#+'
au FileType org      let b:presenting_slide_separator_default = '\v(^|\n)#-{4,}'
au FileType rst      let b:presenting_slide_separator_default = '\v(^|\n)\~{4,}'
au FileType slide    let b:presenting_slide_separator_default = '\v(^|\n)\ze\*'

let g:presenting_statusline = get(g:, 'presenting_statusline', '%{b:presenting_page_current}/%{b:presenting_page_total}')
let g:presenting_top_margin = get(g:, 'presenting_top_margin', 0)
let g:presenting_next = get(g:, 'presenting_next', 'n')
let g:presenting_prev = get(g:, 'presenting_prev', 'p')
let g:presenting_quit = get(g:, 'presenting_quit', 'q')

let g:presenting_figlets = get(g:, 'presenting_figlets', 1)
let g:presenting_font_large = get(g:, 'presenting_font_large', 'small')
let g:presenting_font_small = get(g:, 'presenting_font_small', 'straight')

" Main logic / start the presentation {{{1
function! s:Start()
  " make sure we can parse the current filetype
  let l:filetype = &filetype
  if !exists('b:presenting_slide_separator') && !exists('b:presenting_slide_separator_default')
    echom "set b:presenting_slide_separator for \"" . l:filetype . "\" filetype to enable Presenting.vim"
    return
  endif

  " Parse the document into pages
  let l:pages = s:Parse()
  call s:Format()

  if empty(l:pages)
    echo "No page detected!"
    return
  endif

  " avoid '"_SLIDE_" [New File]' msg by using silent
  execute 'silent tabedit _SLIDE_'.localtime().'_'
  let b:pages = l:pages
  let b:page_number = 0
  let b:max_page_number = len(b:pages) - 1

  " some options for the buffer
  setlocal buftype=nofile
  setlocal cmdheight=1
  setlocal nocursorcolumn nocursorline
  setlocal nofoldenable
  setlocal nonumber norelativenumber
  setlocal noswapfile
  setlocal wrap
  setlocal linebreak
  setlocal breakindent
  setlocal nolist
  let &filetype=l:filetype

  call s:ShowPage(0)
  call s:UpdateStatusLine()

  " commands for the navigation
  command! -buffer -count=1 PresentingNext call s:NextPage(<count>)
  command! -buffer -count=1 PresentingPrev call s:PrevPage(<count>)
  command! -buffer PresentingExit call s:Exit()

  " mappings for the navigation
  execute 'nnoremap <buffer> <silent> ' . g:presenting_next . ' :PresentingNext<CR>'
  execute 'nnoremap <buffer> <silent> ' . g:presenting_prev . ' :PresentingPrev<CR>'
  execute 'nnoremap <buffer> <silent> ' . g:presenting_quit . ' :PresentingExit<CR>'
endfunction

command! StartPresenting call s:Start()
command! PresentingStart call s:Start()

" Functions for Navigation {{{1
function! s:ShowPage(page_no)
  if a:page_no < 0 || a:page_no >= len(b:pages)
    return
  endif
  let b:page_number = a:page_no

  " replace content of buffer with the next page
  setlocal noreadonly modifiable
  " avoid "--No lines in buffer--" msg by using silent
  silent %delete _
  call append(0, b:pages[b:page_number])
  call append(0, map(range(1,g:presenting_top_margin), '""'))
  execute ":normal! gg"
  call append(line('$'), map(range(1,winheight('%')-(line('w$')-line('w0')+1)), '""'))
  setlocal readonly nomodifiable

  call s:UpdateStatusLine()

  " move cursor to the top
  execute ":normal! gg"
endfunction

function! s:NextPage(count)
  let b:page_number = min([b:page_number+a:count, b:max_page_number])
  call s:ShowPage(b:page_number)
endfunction

function! s:PrevPage(count)
  let b:page_number = max([b:page_number-a:count, 0])
  call s:ShowPage(b:page_number)
endfunction

function! s:Exit()
  bwipeout!
endfunction

function! s:UpdateStatusLine()
  let b:presenting_page_current = b:page_number + 1
  let b:presenting_page_total = len(b:pages)
  let &l:statusline = g:presenting_statusline
endfunction

" Parsing & Formatting {{{1
function! s:Parse()
  let l:sep = exists('b:presenting_slide_separator') ? b:presenting_slide_separator : b:presenting_slide_separator_default
  return map(split(join(getline(1, '$'), "\n"), l:sep), 'split(v:val, "\n")')
endfunction

function! s:Format()
  " The {s:filetype}#format() autoload function processes one line of
  " text at a time. Some lines may depend on a prior line, such as
  " numbering and indenting numbered lists. This state information is
  " passed into {s:filetyepe}#format() through the state Dictionary
  " variable. The function will use it however it needs to. s:Format()
  " doesn't care how it's used, but must keep the state variable intact
  " for each successive call to the autoload function.
  let state = {}

  try
    for i in range(0,len(s:pages)-1)
      let replacement_page = []
      for j in range(0, len(s:pages[i])-1)
        let [new_text, state] = {s:filetype}#format(s:pages[i][j], state)
        let replacement_page += new_text
      endfor
      let s:pages[i] = replacement_page
    endfor
  catch /E117/
    echo 'Auto load function '.s:filetype.'#format(text, state) does not exist.'
  endtry
endfunction

" }}}
" vim:ts=2:sw=2:expandtab:foldmethod=marker
