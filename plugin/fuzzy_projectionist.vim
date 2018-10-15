if exists('g:loaded_fuzzy_projectionist') || &cp || !has('lambda')
  finish
endif
let g:loaded_fuzzy_projectionist = 1
let b:projections = {}

" " for if you're ever adding windows support {{{
" function! fuzzy_projectionist#slash(...) abort
"   let s = exists('+shellslash') && !&shellslash ? '\' : '/'
"   return a:0 ? tr(a:1, '/', s) : s
" endfunction
" " normalizes slashes
" function! s:slash(str) abort
"   return tr(a:str, fuzzy_projectionist#slash(), '/')
" endfunction " }}}

function! s:count_stars(proj_glob) abort
  let nmatches = len(split(a:proj_glob, '\*', 1)) - 1
  return nmatches
endfunction

function! s:glob_to_regex(g) abort
  let glob = a:g
  let glob = substitute(glob, '\.', '\\.', 'g')
  let glob = substitute(glob, "'", "\\'", "g")
  if (s:count_stars(glob) > 1)
    " cater for ..../k*k where k = ([^\/\*])?
    let glob = substitute(glob, '\([^/\*]*\)\*\([^/\*]*\)$', "\\1________FZP_FILENAME________\\2", "g")
    " any remaining **/ glob is the regex .*
    " (allow xxx/**/*.txt to match xxx/thing.txt)
    let glob = substitute(glob, '/\*\**/', "/*", "g")
    " any remaining **, ***, ****** sequence is the regex .*
    let glob = substitute(glob, '\*\**', ".*", "g")
    " filenames are just non-slash chars
    let glob = substitute(glob, '________FZP_FILENAME________', "[^/]*", "g")
  else
    let glob = substitute(glob, '\*', ".*", "g")
  endif
  let glob = glob . "$"
  return glob
endfunction

" try to use projectionist itself? {{{
" function! s:call_projectionist_glob(g) abort
"   let glob = a:g
"   if (s:count_stars(glob) == 1)
"     let glob = substitute(glob, '\*', '**/*', 'g')
"   endif
"   " this is what projectionist does?
"   let glob = substitute(glob, '[^\/]*\ze\*\*[\/]\*', '', 'g')
"   let matches = projectionist#glob(glob, 1)
"   return matches
"   " return map(matches, 'fnameescape(v:val)')
" endfunction "}}}

function! s:maxdir(g) abort
  let upto_star = matchstr(a:g, '.*\ze\*')
  return matchstr(upto_star, '.*\ze/')
endfunction

function! s:after_glob(g) abort
  return matchstr(a:g, '[^\*]*$')
endfunction

function! s:glob_portion(g) abort
  let maxdir = len(s:maxdir(a:g))
  return a:g[maxdir+1:]
endfunction

function! s:fzf_source(g) abort
  let cmd = ''
  if executable('fd')
    let glob = s:glob_portion(a:g)
    let cmd = 'fd --type f --full-path '. "'" . s:glob_to_regex(glob) . "'"
  else
    let glob = s:glob_portion(a:g)
    " strip leading ./ as well to match fd and plain vim-projectionist
    " POSIX compatible
    let cmd = 'find . -regex ' . "'".s:glob_to_regex(glob)."'". ' | sed "s|^\./||"'
  endif
  let after = s:after_glob(a:g)
  let cmd = cmd . '| sed "s|'.after.'\$||"'
  return cmd
endfunction

func! s:sink(lines, dir, after) abort
  if len(a:lines) < 2 | return | endif
  let cmd = get({'ctrl-x': 'split',
               \ 'ctrl-v': 'vertical split',
               \ 'ctrl-t': 'tabe'}, a:lines[0], 'e')
  let list = a:lines[1:]

  let first = a:dir . list[0] . a:after
  execute cmd escape(first, ' %#\')
endfunc

function! fuzzy_projectionist#projection_for_type(type) abort
  if exists('b:projections ') && b:projections != {}
    let cwd = getcwd()
    if has_key(b:projections, cwd)
      let projections_for_cwd = b:projections[cwd]
      if has_key(projections_for_cwd, a:type)
        let glob   = projections_for_cwd[a:type]
        let source = s:fzf_source(glob)
        let dir    = cwd."/".s:maxdir(glob)."/"
        let after  = s:after_glob(glob)
        let Func   = { lines -> s:sink(lines, dir, after) }
        let fzf_options = '--expect=ctrl-t,ctrl-v,ctrl-x --prompt "projectionist:'.a:type.'> "'
        let opts   = fzf#wrap(a:type, { 'source': source, 'dir': dir, 'sink*': Func, 'options': fzf_options }, 0)
        call fzf#run(opts)
      else
        echo 'No ' . a:type . ' projections for this project'
      endif
    else
      echo 'No projections for this project'
    endif
  else
    echo 'No projections.'
  endif
endfunction

function! fuzzy_projectionist#choose_projection() abort
  if exists('b:projections') && b:projections != {}
    let cwd = getcwd()
    if has_key(b:projections, cwd)
      let options = ""
      let index = 1
      let projections = items(b:projections[cwd])
      for [type, path] in projections
        let options = options . "&" . index . " " . type . "\n"
        let index = index + 1
      endfor
      let chosen_index = str2nr(confirm("Choose a thing", options, 0)) - 1
      call fuzzy_projectionist#projection_for_type(projections[chosen_index][0])
    else
      echo 'No projections for this project'
    endif
  else
    echo 'No projections'
  endif
endfunction

function! fuzzy_projectionist#add_projections() abort
  let raw_projections = projectionist#navigation_commands()
  if raw_projections != {}
    call s:extract_projections(raw_projections)
  endif
endfunction

function! fuzzy_projectionist#available_projections() abort
  if exists('b:projections')
    return b:projections
  endif
  return {}
endfunction

function! s:extract_projections(raw_projections) abort
  let b:projections = {}
  for [type, projections] in items(a:raw_projections)
   for [working_dir, projection_path] in projections
     if !has_key(b:projections, working_dir)
       let b:projections[working_dir] = {}
     endif
     let b:projections[working_dir][type] = projection_path
   endfor
   call fuzzy_projectionist#define_command(type)
  endfor
endfunction

function! fuzzy_projectionist#define_command(command) abort
  execute 'command! -buffer -bar -bang -nargs=*'
        \ 'F' . substitute(a:command, '\A', '', 'g')
        \ ':call fuzzy_projectionist#projection_for_type("'.a:command.'")'
endfunction

augroup fuzzy_projectionist
  autocmd!
  autocmd User ProjectionistActivate call fuzzy_projectionist#add_projections()
augroup END
