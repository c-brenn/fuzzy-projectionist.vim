if exists('g:loaded_fzf_projectionist') || &cp
  finish
endif
let g:loaded_fzf_projectionist = 1

function! fzf_projectionist#search_projections(type) abort
  if exists('b:projections ') && b:projections != {}
    if has_key(b:projections, a:type)
      let subset =  b:projections[a:type]
      let cwd = getcwd()
      for pair in subset
        if cwd =~ pair[0]
          let str = fnamemodify(pair[1], ":p:h")
          exe 'FZF ' . str
          return
        endif
      endfor
      echo 'no projections of that type were found in this project'
    else
      echo 'no projections of that type were found'
    endif
  else
    echo 'no projections found'
  endif
endfunction

function! fzf_projectionist#add_projections() abort
  let b:projections = projectionist#navigation_commands()
  if b:projections != {}
    for [type, stuff] in items(b:projections)
      execute 'command! '
            \ 'FZF' . type
            \ " call fzf_projectionist#search_projections('" . type ."')"
    endfor
  endif
endfunction

augroup fzf_projectionist
  autocmd!
  autocmd User ProjectionistActivate call fzf_projectionist#add_projections()
augroup END
