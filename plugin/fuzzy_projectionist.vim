if &compatible || !has('lambda')
  finish
endif

if !exists('g:fuzzy_projectionist_depth')
  let g:fuzzy_projectionist_depth = 0
endif

augroup fuzzy_projectionist
  autocmd!
  autocmd User ProjectionistActivate call fuzzy_projectionist#add_projections()
augroup END
