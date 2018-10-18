if &compatible || !has('lambda')
  finish
endif

augroup fuzzy_projectionist
  autocmd!
  autocmd User ProjectionistActivate call fuzzy_projectionist#add_projections()
augroup END
