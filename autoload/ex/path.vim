" path: string of file path
" system: options { 'windows' 'unix' }
function ex#path#translate( path, system )
  if a:system == 'windows'
    return substitute( a:path, "\/", "\\", "g" )
  elseif a:system == 'unix'
    return substitute( a:path, "\\", "\/", "g" )
  else
    call ex#warning('unknown OS: ' . system)
    return path
  endif
endfunction

" vim:ts=2:sw=2:sts=2
