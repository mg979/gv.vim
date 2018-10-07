let s:begin = '^[^0-9]*[0-9]\{4}-[0-9]\{2}-[0-9]\{2}\s\+'

"------------------------------------------------------------------------------
" Setup {{{1
"------------------------------------------------------------------------------

function! gv#sha(...)
  return matchstr(get(a:000, 0, getline('.')), s:begin.'\zs[a-f0-9]\+')
endfunction

function! gv#start(bang, visual, line1, line2, args) abort
  if !exists('g:loaded_fugitive')
    return s:warn('fugitive not found')
  endif

  let git_dir = s:git_dir()
  if empty(git_dir)
    return s:warn('not in git repo')
  endif

  let fugitive_repo = fugitive#repo(git_dir)
  let cd = exists('*haslocaldir') && haslocaldir() ? 'lcd' : 'cd'
  let cwd = getcwd()
  let root = fugitive_repo.tree()
  try
    if cwd !=# root
      execute cd escape(root, ' ')
    endif
    if a:args =~ '?$'
      if len(a:args) > 1
        return s:warn('invalid arguments')
      endif
      call s:check_buffer(fugitive_repo, expand('%'))
      call s:gl(bufnr(''), a:visual)
    else
      let log_opts = extend(gv#shellwords(a:args), s:log_opts(fugitive_repo, a:bang, a:visual, a:line1, a:line2))
      call s:setup(git_dir, fugitive_repo.config('remote.origin.url'))
      call s:list(fugitive_repo, log_opts)
      call fugitive#detect(@#)
    endif
  catch
    return s:warn(v:exception)
  finally
    if getcwd() !=# cwd
      cd -
    endif
  endtry
endfunction

"------------------------------------------------------------------------------

function! s:gl(buf, visual)
  if !exists(':Gllog')
    return
  endif
  tab split
  silent execute a:visual ? "'<,'>" : "" 'Gllog'
  call setloclist(0, insert(getloclist(0), {'bufnr': a:buf}, 0))
  b #
  lopen
  xnoremap <buffer> o :call <sid>gld()<cr>
  nnoremap <buffer> o <cr><c-w><c-w>
  nnoremap <buffer> O :call <sid>gld()<cr>
  nnoremap <buffer> q :tabclose<cr>
  call matchadd('Conceal', '^fugitive://.\{-}\.git//')
  call matchadd('Conceal', '^fugitive://.\{-}\.git//\x\{7}\zs.\{-}||')
  setlocal concealcursor=nv conceallevel=3 nowrap
  let w:quickfix_title = 'o: open / o (in visual): diff / O: open (tab) / q: quit'
endfunction

function! s:gld() range
  let [to, from] = map([a:firstline, a:lastline], 'split(getline(v:val), "|")[0]')
  execute (tabpagenr()-1).'tabedit' escape(to, ' ')
  if from !=# to
    execute 'vsplit' escape(from, ' ')
    windo diffthis
  endif
endfunction

"------------------------------------------------------------------------------

function! s:setup(git_dir, git_origin)
  call s:tabnew()
  call s:scratch()

  if exists('g:fugitive_github_domains')
    let domain = join(map(extend(['github.com'], g:fugitive_github_domains),
          \ 'escape(substitute(split(v:val, "://")[-1], "/*$", "", ""), ".")'), '\|')
  else
    let domain = '.*github.\+'
  endif
  " https://  github.com  /  junegunn/gv.vim  .git
  " git@      github.com  :  junegunn/gv.vim  .git
  let pat = '^\(https\?://\|git@\)\('.domain.'\)[:/]\([^@:/]\+/[^@:/]\{-}\)\%(.git\)\?$'
  let origin = matchlist(a:git_origin, pat)
  if !empty(origin)
    let scheme = origin[1] =~ '^http' ? origin[1] : 'https://'
    let b:git_origin = printf('%s%s/%s', scheme, origin[2], origin[3])
  endif
  let b:git_dir = a:git_dir
endfunction

function! s:log_opts(fugitive_repo, bang, visual, line1, line2)
  if a:visual || a:bang
    let g:gv_file = expand('%')
    call s:check_buffer(a:fugitive_repo, g:gv_file)
    return a:visual ? [printf('-L%d,%d:%s', a:line1, a:line2, g:gv_file)] : ['--follow', g:gv_file]
  else
    silent! unlet g:gv_file
  endif
  return ['--graph']
endfunction

function! s:list(fugitive_repo, log_opts)
  let default_opts = ['--color=never', '--date=short', '--format=%cd %h%d %s (%an)']
  let git_args = ['log'] + default_opts + a:log_opts
  let git_log_cmd = call(a:fugitive_repo.git_command, git_args, a:fugitive_repo)

  let repo_short_name = fnamemodify(substitute(a:fugitive_repo.dir(), '[\\/]\.git[\\/]\?$', '', ''), ':t')
  let bufname = repo_short_name.' '.join(a:log_opts)
  silent exe (bufexists(bufname) ? 'buffer' : 'file') fnameescape(bufname)

  call s:fill(git_log_cmd)
  setlocal nowrap tabstop=8 cursorline iskeyword+=#

  if !exists(':Gbrowse')
    doautocmd <nomodeline> User Fugitive
  endif
  call s:maps()
  call s:syntax()
  redraw
  if exists('g:gv_file')
    nnoremap <silent> <buffer> <nowait> S    :call gv#sbs#show()<cr>
    echohl Label | echo g:gv_file."\t"
    echohl None  | echon 'o: open split / O: open tab / gb: Gbrowse / q: quit / S: show revision'
  else
    echo 'o: open split / O: open tab / gb: Gbrowse / q: quit'
  endif
endfunction

function! s:trim(arg)
  let arg = substitute(a:arg, '\s*$', '', '')
  return arg =~ "^'.*'$" ? substitute(arg[1:-2], "''", '', 'g')
        \ : arg =~ '^".*"$' ? substitute(substitute(arg[1:-2], '""', '', 'g'), '\\"', '"', 'g')
        \ : substitute(substitute(arg, '""\|''''', '', 'g'), '\\ ', ' ', 'g')
endfunction

function! gv#shellwords(arg)
  let words = []
  let contd = 0
  for token in split(a:arg, '\%(\%(''\%([^'']\|''''\)\+''\)\|\%("\%(\\"\|[^"]\)\+"\)\|\%(\%(\\ \|\S\)\+\)\)\s*\zs')
    let trimmed = s:trim(token)
    if contd
      let words[-1] .= trimmed
    else
      call add(words, trimmed)
    endif
    let contd = token !~ '\s\+$'
  endfor
  return words
endfunction

"------------------------------------------------------------------------------

function! s:type(visual)
  if a:visual
    let shas = filter(map(getline("'<", "'>"), 'gv#sha(v:val)'), '!empty(v:val)')
    if len(shas) < 2
      return [0, 0]
    endif
    return ['diff', fugitive#repo().git_command('diff', shas[-1], shas[0])]
  endif

  if exists('b:git_origin')
    let syn = synIDattr(synID(line('.'), col('.'), 0), 'name')
    if syn == 'gvGitHub'
      return ['link', '/issues/'.expand('<cword>')[1:]]
    elseif syn == 'gvTag'
      let tag = matchstr(getline('.'), '(tag: \zs[^ ,)]\+')
      return ['link', '/releases/'.tag]
    endif
  endif

  let sha = gv#sha()
  if !empty(sha)
    return ['commit', FugitiveGenerate(sha, b:git_dir)]
  endif
  return [0, 0]
endfunction

function! s:split(tab)
  if a:tab
    call s:tabnew()
  elseif getwinvar(winnr('$'), 'gv')
    $wincmd w
    enew
  else
    vertical botright new
  endif
  let w:gv = 1
endfunction

function! s:open(visual, ...)
  let [type, target] = s:type(a:visual)

  if empty(type)
    return s:shrug()
  elseif type == 'link'
    return s:browse(target)
  endif

  call s:split(a:0)
  if type == 'commit'
    execute 'e' escape(target, ' ')
    nnoremap <silent> <buffer> gb :Gbrowse<cr>
  elseif type == 'diff'
    call s:scratch()
    call s:fill(target)
    setf diff
  endif
  nnoremap <silent> <nowait> <buffer>        q          :$wincmd w <bar> bdelete!<cr>
  nnoremap <silent> <nowait> <buffer>        <tab>      <c-w><c-w>
  nnoremap <silent> <nowait> <buffer>        [z         :<c-u>call <sid>folds(0)<cr>
  nnoremap <silent> <nowait> <buffer>        ]z         :<c-u>call <sid>folds(1)<cr>
  let bang = a:0 ? '!' : ''
  if exists('#User#GV'.bang)
    execute 'doautocmd <nomodeline> User GV'.bang
  endif
  wincmd p
  echo
endfunction

"------------------------------------------------------------------------------
" Buffers {{{1
"------------------------------------------------------------------------------

function! s:scratch()
  setlocal buftype=nofile bufhidden=wipe noswapfile
endfunction

function! s:fill(cmd)
  setlocal modifiable
  silent execute 'read' escape('!'.a:cmd, '%')
  normal! gg"_dd
  setlocal nomodifiable
endfunction

function! s:syntax()
  setf GV
  syn clear
  syn match gvInfo    /^[^0-9]*\zs[0-9-]\+\s\+[a-f0-9]\+ / contains=gvDate,gvSha nextgroup=gvMessage,gvMeta
  syn match gvDate    /\S\+ / contained
  syn match gvSha     /[a-f0-9]\{6,}/ contained
  syn match gvMessage /.* \ze(.\{-})$/ contained contains=gvTag,gvGitHub,gvJira nextgroup=gvAuthor
  syn match gvAuthor  /.*$/ contained
  syn match gvMeta    /([^)]\+) / contained contains=gvTag nextgroup=gvMessage
  syn match gvTag     /(tag:[^)]\+)/ contained
  syn match gvGitHub  /\<#[0-9]\+\>/ contained
  syn match gvJira    /\<[A-Z]\+-[0-9]\+\>/ contained
  hi def link gvDate   Number
  hi def link gvSha    Identifier
  hi def link gvTag    Constant
  hi def link gvGitHub Label
  hi def link gvJira   Label
  hi def link gvMeta   Conditional
  hi def link gvAuthor String

  syn match gvAdded     "^\W*\zsA\t.*"
  syn match gvDeleted   "^\W*\zsD\t.*"
  hi def link gvAdded    diffAdded
  hi def link gvDeleted  diffRemoved

  syn match diffAdded   "^+.*"
  syn match diffRemoved "^-.*"
  syn match diffLine    "^@.*"
  syn match diffFile    "^diff\>.*"
  syn match diffFile    "^+++ .*"
  syn match diffNewFile "^--- .*"
  hi def link diffFile    Type
  hi def link diffNewFile diffFile
  hi def link diffAdded   Identifier
  hi def link diffRemoved Special
  hi def link diffFile    Type
  hi def link diffLine    Statement
endfunction

function! s:maps()
  nnoremap <silent> <nowait> <buffer>        q          :$wincmd w <bar> bdelete!<cr>
  nnoremap <silent> <nowait> <buffer>        <tab>      <c-w><c-w>
  nnoremap <silent> <nowait> <buffer>        gb         :call <sid>gbrowse()<cr>
  nnoremap <silent> <nowait> <buffer>        <cr>       :call <sid>open(0)<cr>
  nnoremap <silent> <nowait> <buffer>        o          :call <sid>open(0)<cr>
  nnoremap <silent> <nowait> <buffer>        O          :call <sid>open(0, 1)<cr>
  xnoremap <silent> <nowait> <buffer>        <cr>       :<c-u>call <sid>open(1)<cr>
  xnoremap <silent> <nowait> <buffer>        o          :<c-u>call <sid>open(1)<cr>
  xnoremap <silent> <nowait> <buffer>        O          :<c-u>call <sid>open(1, 1)<cr>
  nnoremap          <nowait> <buffer> <expr> .          <sid>dot()
  nnoremap          <nowait> <buffer> <expr> ~          <sid>tilde()
  nnoremap <silent> <nowait> <buffer> <expr> j          <sid>move('')
  nnoremap <silent> <nowait> <buffer> <expr> k          <sid>move('b')
  xnoremap <silent> <nowait> <buffer> <expr> ]          <sid>move('')
  xnoremap <silent> <nowait> <buffer> <expr> [          <sid>move('b')
  nnoremap <silent> <nowait> <buffer>        [z         :<c-u>call <sid>folds(0)<cr>
  nnoremap <silent> <nowait> <buffer>        ]z         :<c-u>call <sid>folds(1)<cr>

  nmap              <nowait> <buffer> <C-n> jo
  nmap              <nowait> <buffer> <C-p> ko
  xmap              <nowait> <buffer> <C-n> ]ogv
  xmap              <nowait> <buffer> <C-p> [ogv
endfunction

"------------------------------------------------------------------------------
" Git {{{1
"------------------------------------------------------------------------------

function! s:git_dir()
  if empty(get(b:, 'git_dir', ''))
    return fugitive#extract_git_dir(expand('%:p'))
  endif
  return b:git_dir
endfunction

function! s:tracked(fugitive_repo, file)
  call system(a:fugitive_repo.git_command('ls-files', '--error-unmatch', a:file))
  return !v:shell_error
endfunction

function! s:check_buffer(fugitive_repo, current)
  if empty(a:current)
    throw 'untracked buffer'
  elseif !s:tracked(a:fugitive_repo, a:current)
    throw a:current.' is untracked'
  endif
endfunction

"------------------------------------------------------------------------------
" Actions {{{1
"------------------------------------------------------------------------------

function! s:gbrowse()
  let sha = gv#sha()
  if empty(sha)
    return s:shrug()
  endif
  execute 'Gbrowse' sha
endfunction

function! s:dot()
  let sha = gv#sha()
  return empty(sha) ? '' : ':Git  '.sha."\<s-left>\<left>"
endfunction

function! s:tilde()
  if !exists('g:loaded_gitgutter')
    call s:warn('GitGutter not loaded.')
    return
  endif
  let sha = gv#sha()
  let g:gitgutter_diff_base = sha
  GitGutter
  call s:warn('GitGutter diff base set to commit '.sha)
endfunction

function! <sid>folds(down)
  if len(tabpagebuflist()) == 1 || exists('s:moved')
    silent! unlet s:moved
    normal o
  endif
  wincmd l
  if a:down
    if foldlevel('.') > 0 | silent! normal! zczj
    else                  | silent! normal! zj
    endif                 | silent! normal! zo
  else
    if foldlevel('.') > 0 | silent! normal! zczkzkzj
    else                  | silent! normal! zkzkzj
    endif                 | silent! normal! zo[z
  endif
  wincmd h
  silent! exe "normal! z\<cr>"
endfunction

"------------------------------------------------------------------------------
" Helpers {{{1
"------------------------------------------------------------------------------

function! s:warn(message)
  echohl WarningMsg | echom a:message | echohl None
endfunction

function! s:shrug()
  call s:warn('¯\_(ツ)_/¯')
endfunction

function! s:move(flag)
  let s:moved = 1
  let [l, c] = searchpos(s:begin, a:flag)
  return l ? printf('%dG%d|', l, c) : ''
endfunction

function! s:browse(url)
  call netrw#BrowseX(b:git_origin.a:url, 0)
endfunction

function! s:tabnew()
  execute (tabpagenr()-1).'tabnew'
endfunction
