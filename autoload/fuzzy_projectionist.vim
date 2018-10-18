if &compatible || !has('lambda')
  finish
endif

function! s:count_stars(proj_glob) abort
  let nmatches = len(split(a:proj_glob, '\*', 1)) - 1
  return nmatches
endfunction

func! s:upto_star(g)
  return matchstr(a:g, '[^\*]*\ze\*')
endfunc

func! s:maxdir(g) abort
  return matchstr(s:upto_star(a:g), '.*\ze/\ze')
endfunc

func! s:after_glob(g) abort
  return matchstr(a:g, '[^\*]*$')
endfunc

func! s:glob_portion(g) abort
  let maxdir = len(s:maxdir(a:g))
  return a:g[maxdir:]
endfunc

func! s:before_glob(g) abort
  let gp = s:glob_portion(a:g)
  return s:upto_star(gp)
endfunc

func! s:glob_literals(gl)
  " glob dots are literal dots
  return glob
endfunc

function! s:glob_to_regex(g) abort
  let glob = a:g
  let glob = substitute(glob, '\.', '\\.', 'g')
  " glob quotes are literal quotes
  let glob = substitute(glob, "'", "\\'", "g")
  if (s:count_stars(glob) > 1)
    " cater for ..../k*k where k = not slash or *
    " inside [^], any char is a literal except ]
    let glob = substitute(glob, '\v([^/*]*)\*([^/*]*)$',
          \   "\\1________FZP_FILENAME________\\2", "g")
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

function! s:source_fd(g)
  let glob = s:glob_portion(a:g)
  let cmd = 'fd --type f --full-path '. "'" . s:glob_to_regex(glob) . "'"
  return s:sed_before_after(a:g, cmd)
endfunction

function! s:source_find(g)
  let glob = s:glob_portion(a:g)
  " strip leading ./ as well to match fd and plain vim-projectionist
  " POSIX compatible
  let cmd = 'find . -regex ' . "'".s:glob_to_regex(glob)."'"
  return s:sed_before_after(a:g, cmd)
endfunction

func! s:sed_before_after(g, cmd)
  let before = s:before_glob(a:g)
  let after = s:after_glob(a:g)
  return a:cmd . '| sed -e "s|^\./||" -e "s|'.after.'\$||" -e "s|^'.before.'||"'
endfunc

function! s:fzf_source(dir, g) abort
  let maxdir = s:maxdir(a:g)
  let before = s:before_glob(a:g)
  let after  = s:after_glob(a:g)
  if s:count_stars(a:g) == 0
    return 'true'
  endif
  if executable('fd')
    let cmd = s:source_fd(a:g)
  else
    let cmd =  s:source_find(a:g)
  endif
  let cmd = 'cd ' . shellescape(a:dir.'/'.maxdir). ' && ' . cmd . ''
  " see s:decode
  let cmd = cmd . ' | awk ''{print "'
        \ . (a:dir) . ':'
        \ . (maxdir) . ':'
        \ . (before) . ':'
        \ . (after) . ':'
        \ . '" $0 }''; '
  return cmd
endfunction

func! s:decode(line)
  let [workdir, maxdir, before, after, match] = split(a:line, ':')
  return escape( workdir . '/' . maxdir . before . match . after , ' %#\')
endfunc

func! s:sink(lines, d_workdir, d_glob, ...) abort
  let d_cmd = get(a:, 1, 'e')
  let should_confirm = get(a:, 2, 1)
  if len(a:lines) < 2 | return | endif
  let query = a:lines[0]
  let cmd = get({'ctrl-x': 'split',
        \ 'ctrl-v': 'vertical split',
        \ 'ctrl-t': 'tabe'}, a:lines[1], d_cmd)
  if len(a:lines) < 3
    " user matched nothing
    let cd = exists('*haslocaldir') && haslocaldir() ? 'lcd' : 'cd'
    let cwd = getcwd()
    try
      " go to projectionist root first, so prompted relative filepath is correct
      exec 'Pcd'
      let newfile = escape(a:d_workdir . '/' . s:maxdir(a:d_glob) 
            \ . s:before_glob(a:d_glob) . query . s:after_glob(a:d_glob), ' %#\')
      let display = fnamemodify(newfile, ":~:.")
      let dir = fnamemodify(newfile, ":p:h")
      if !should_confirm || 1 == confirm('create new file '.display.' ?', "&Yes (default)\n&No")
        call mkdir(dir, "p")
        execute cmd newfile
      endif
    catch
      return
    finally
      exec cd fnameescape(cwd)
    endtry
    return
  endif
  let list = a:lines[2:]
  let first = s:decode(list[0])
  execute cmd first
endfunc

func! s:patterns_to_cmd(patterns)
  let uniq = {}
  " build a ;-separated list of commands to deliver all the different
  " projection patterns in s:decode()-able format
  let accumulated = ''
  for [dir, glob] in a:patterns
    if has_key(uniq, dir) && has_key(uniq[dir], glob) | continue | endif
    let uniq[dir] = {} | let uniq[dir][glob] = 1
    let accumulated = accumulated . s:fzf_source(dir, glob)
  endfor
  return accumulated
endfunc

func! fuzzy_projectionist#open_projection(type, patterns, ...)
  let initial_query = get(a:, 1, '')
  let depth = g:fuzzy_projectionist_depth
  let extra_opts = get(a:, 2, [])

  if initial_query != ''
      let extra_opts = extra_opts + ['-1','--query='.initial_query]
  endif
  if g:fuzzy_projectionist_preview == 1
    let decode='{1}/{2}{3}{5}{4}'
    let extra_opts = extra_opts +  ['--preview', 'head -n 100 '.decode ]
  endif

  if len(a:patterns) == 0 | return | endif
  let limited  = a:patterns[:depth - 1]
  let cmd = s:patterns_to_cmd(limited)
  " use the first listed pattern (the nearest workdir) for use as a file
  " creation default
  let opts   = fzf#wrap(a:type, {
        \'source': cmd,
        \'sink*': { lines -> s:sink(lines, limited[0][0], limited[0][1]) },
        \'options': extra_opts + [
        \ '--expect=ctrl-t,ctrl-v,ctrl-x',
        \ '--with-nth=5',
        \ '-d:',
        \ '--print-query',
        \ '--prompt=projectionist:'.a:type.'> '
        \] }, 0)
  return fzf#run(opts)
endfunc

function! fuzzy_projectionist#projection_for_type(type) abort
  if exists('b:fuzzy_projections') && b:fuzzy_projections != {} 
        \&& has_key(b:fuzzy_projections, a:type)
    let patterns = b:fuzzy_projections[a:type]
    call fuzzy_projectionist#open_projection(a:type, patterns, '')
  endif
endfunction

function! fuzzy_projectionist#choose_projection() abort
  if exists('b:fuzzy_projections') && b:fuzzy_projections != {}
    let index = 1
    let options = ''
    let types = []
    for [type, projections] in items(b:fuzzy_projections)
      let options = options . "&" . index . " " . type . "\n"
      let index = index + 1
      let types = types + [type]
    endfor
    let chosen_index = str2nr(confirm("Choose a thing", options, 0)) - 1
    if chosen_index < 0 | return | endif
    let chosen_type = types[chosen_index]
    call fuzzy_projectionist#projection_for_type(chosen_type)
  endif
endfunction

function! fuzzy_projectionist#add_projections() abort
  let b:fuzzy_projections = projectionist#navigation_commands()
  if b:fuzzy_projections != {}
    for [type, projections] in items(b:fuzzy_projections)
      " for [working_dir, glob] in projections
      " endfor
      call fuzzy_projectionist#define_command(type, projections)
    endfor
  endif
endfunction

function! fuzzy_projectionist#available_projections() abort
  if exists('b:fuzzy_projections')
    return b:fuzzy_projections
  endif
  return {}
endfunction

function! fuzzy_projectionist#define_command(command, projections) abort
  execute 'command! -buffer -bar -bang -nargs=?'
        \ 'F' . substitute(a:command, '\A', '', 'g')
        \ ':call fuzzy_projectionist#open_projection('
        \   .string(a:command).', '.string(a:projections).', <f-args>)'
endfunction

