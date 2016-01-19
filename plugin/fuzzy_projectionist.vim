if exists('g:loaded_fuzzy_projectionist') || &cp
  finish
endif
let g:loaded_fuzzy_projectionist = 1
let b:projections = {}
let g:fuzzy_projectionist_finder_command = 'FZF'

function! fuzzy_projectionist#projection_for_type(type) abort
  if exists('b:projections ') && b:projections != {}
    let cwd = getcwd()
    if has_key(b:projections, cwd)
      let projections_for_cwd = b:projections[cwd]
      if has_key(projections_for_cwd, a:type)
        let dir_to_search = projections_for_cwd[a:type]
        exe g:fuzzy_projectionist_finder_command . ' ' . dir_to_search
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
     let b:projections[working_dir][type] = fnamemodify(projection_path, ":p:h")
   endfor
  endfor
endfunction

augroup fuzzy_projectionist
  autocmd!
  autocmd User ProjectionistActivate call fuzzy_projectionist#add_projections()
augroup END
