function! cmp_vimtex#invoke(func, args) abort
  if a:func =~# '^v:lua\.'
    return luaeval(printf('%s(_A[1], _A[2], _A[3])', matchstr(a:func, '^v:lua\.\zs.*')), a:args)
  endif
  return nvim_call_function(a:func, a:args)
endfunction

"function! cmp_vimtex#parse_bibtex() abort
"  call vimtex#paths#pushd(b:vimtex.root)
"  let l:entries = []
"  for l:file in vimtex#bib#files()
"    let l:entries += vimtex#parser#bib(l:file, {'backend': 'vim'})
"  endfor
"  call vimtex#paths#popd()
"  return l:entries
"endfunction

function! cmp_vimtex#parse_bibtex(file) abort
  let l:entries = []
  let l:entries += vimtex#parser#bib(a:file, {'backend': 'vim'})
  return l:entries
endfunction

function! cmp_vimtex#parse_with_vim_r() abort
  lua vim.g.start_date = os.date("%X")
  lua vim.g.start_time = os.clock()
  echom "1_begin_date: " g:start_date

  echom string(g:cmp_vimtex_parsing)
  if g:cmp_vimtex_parsing.to_be_parsed[0]
      g:cmp_vimtex_parsing.is_being_parsed = g:cmp_vimtex_parsing.to_be_parsed[0]
      let l:file = g:cmp_vimtex_parsing.to_be_parsed[0]
      unlet g:cmp_vimtex_parsing.to_be_parsed[0]
  endif

  if !filereadable(l:file)
    return []
  endif

  "The following entries are used only for the current file.
  let g:cmp_vimtex_parsing = {
    \ 'data' : [],
    \ 'current' : {},
    \ 'strings' : {},
    \ 'entries' : [],
    \ 'indexed' : 0,
    \ 'lnum' : -1,
    \ }
  lua logger(os.date("initialized: %X"))
  lua logger(os.clock())
  " Should be initialized in lua, or superseded by vim.g.cmp_vimtex_bib_files.
  let g:cmp_vimtex_parsing['data'] = readfile(l:file)

  lua vim.schedule(vim.fn['cmp_vimtex#parse_r'])
  return
endfunction

function! cmp_vimtex#parse_r() abort
  
  let l:current_lines = 0
  let l:beg = g:cmp_vimtex_parsing.lnum + 1
  let l:end = l:beg + 99
  let l:arr = g:cmp_vimtex_parsing.data[beg:end]
  unlet l:beg
  unlet l:end

  for l:line in l:arr
    let g:cmp_vimtex_parsing.lnum += 1
    let l:current_lines += 1

    if empty(g:cmp_vimtex_parsing.current)
      if cmp_vimtex#parse_type(g:cmp_vimtex_parsing.file, g:cmp_vimtex_parsing.lnum, l:line, g:cmp_vimtex_parsing.current, g:cmp_vimtex_parsing.strings, g:cmp_vimtex_parsing.entries)
        let g:cmp_vimtex_parsing.current = {}
      endif
      continue
    endif

    if g:cmp_vimtex_parsing.current.type ==# 'string'
      if cmp_vimtex#parse_string(l:line, g:cmp_vimtex_parsing.current, g:cmp_vimtex_parsing.strings)
        let g:cmp_vimtex_parsing.current = {}
      endif
    else
      if cmp_vimtex#parse_entry(l:line, g:cmp_vimtex_parsing.current, g:cmp_vimtex_parsing.entries)
        let g:cmp_vimtex_parsing.current = {}
      endif
    endif

    "The 100th line of the current batch should be the last to be indexed on
    "the current cycle.
    if l:current_lines >= 100
      unlet l:current_lines
      unlet l:arr
      lua vim.defer_fn(function() vim.fn['cmp_vimtex#parse_r']() end, 10)
      break
    endif
  endfor

  unlet g:cmp_vimtex_parsing.data
  unlet g:cmp_vimtex_parsing.current
  unlet g:cmp_vimtex_parsing.indexed
  unlet g:cmp_vimtex_parsing.lnum
  "Set vim.g.cmp_vimtex_bib_files for the current file.
  let g:cmp_vimtex_bib_files[g:cmp_vimtex_parsing.file].data = map(g:cmp_vimtex_parsing.entries, 'cmp_vimtex#parse_entry_body(v:val, g:cmp_vimtex_parsing.strings)')
  let g:cmp_vimtex_bib_files[g:cmp_vimtex_parsing.file].required_by += g:cmp_vimtex_parsing.file
  unlet g:cmp_vimtex_parsing.is_being_parsed
  unlet g:cmp_vimtex_parsing.strings
  unlet g:cmp_vimtex_parsing.entries

  "
  "Should parse the remaining bibtex files
  "if some_files_remaining...

  "Only at this point unlet g:cmp_vimtex_parsing
  unlet g:cmp_vimtex_parsing

  " Benchmarking code.
  lua vim.g.end_time = os.clock()
  lua vim.g.end_date = os.date("%X")
  echom "elapsed time: " (g:end_time - g:start_time)
  echom "begin time: " (g:start_date)
  echom "end time: " (g:end_time)

  lua vim.defer_fn(function() parse_response() end, 10)
endfunction

function! cmp_vimtex#parse_with_vim(file) abort " {{{1
  " Adheres to the format description found here:
  " http://www.bibtex.org/Format/

  lua vim.g.start_time = os.clock()
  if !filereadable(a:file)
    return []
  endif

  let l:current = {}
  let l:strings = {}
  let l:entries = []
  let l:lnum = 0
  let l:start_time = reltime()
  let l:bib_file = readfile(a:file)
  lua vim.g.begin_for_time = os.clock()
  for l:line in l:bib_file
    let l:lnum += 1

    if empty(l:current)
      if cmp_vimtex#parse_type(a:file, l:lnum, l:line, l:current, l:strings, l:entries)
        let l:current = {}
      endif
      continue
    endif

    if l:current.type ==# 'string'
      if cmp_vimtex#parse_string(l:line, l:current, l:strings)
        let l:current = {}
      endif
    else
      if cmp_vimtex#parse_entry(l:line, l:current, l:entries)
        let l:current = {}
      endif
    endif
  endfor
  lua vim.g.end_for_time = os.clock()

  let l:tmp = map(l:entries, 'cmp_vimtex#parse_entry_body(v:val, l:strings)')
  lua vim.g.end_time = os.clock()
  echom "elapsed time:" (g:end_time - g:start_time)
  echom "initial time: " (g:begin_for_time - g:start_time)
  echom "for time: " (g:end_for_time - g:begin_for_time)
  echom "map time: " (g:end_time - g:end_for_time)
  return l:tmp
endfunction


function! cmp_vimtex#parse_type(file, lnum, line, current, strings, entries) abort " {{{1
  let l:matches = matchlist(a:line, '\v^\@(\w+)\s*\{\s*(.*)')
  if empty(l:matches) | return 0 | endif

  let l:type = tolower(l:matches[1])
  if index(['preamble', 'comment'], l:type) >= 0 | return 0 | endif

  let a:current.level = 1
  let a:current.body = ''
  let a:current.vimtex_file = a:file
  let a:current.vimtex_lnum = a:lnum

  if l:type ==# 'string'
    return cmp_vimtex#parse_string(l:matches[2], a:current, a:strings)
  else
    let l:matches = matchlist(l:matches[2], '\v^([^, ]*)\s*,\s*(.*)')
    let a:current.type = l:type
    let a:current.key = l:matches[1]

    return empty(l:matches[2])
          \ ? 0
          \ : cmp_vimtex#parse_entry(l:matches[2], a:current, a:entries)
  endif
endfunction

function! cmp_vimtex#parse_string(line, string, strings) abort " {{{1
  let a:string.level += cmp_vimtex#count(a:line, '{') - cmp_vimtex#count(a:line, '}')
  if a:string.level > 0
    let a:string.body .= a:line
    return 0
  endif

  let a:string.body .= matchstr(a:line, '.*\ze}')

  let l:matches = matchlist(a:string.body, '\v^\s*(\w+)\s*\=\s*"(.*)"\s*$')
  if !empty(l:matches) && !empty(l:matches[1])
    let a:strings[l:matches[1]] = l:matches[2]
  endif

  return 1
endfunction

function! cmp_vimtex#parse_entry(line, entry, entries) abort " {{{1
  let a:entry.level += cmp_vimtex#count(a:line, '{') - cmp_vimtex#count(a:line, '}')
  if a:entry.level > 0
    let a:entry.body .= a:line
    return 0
  endif

  let a:entry.body .= matchstr(a:line, '.*\ze}')

  call add(a:entries, a:entry)
  return 1
endfunction


function! cmp_vimtex#parse_entry_body(entry, strings) abort " {{{1
  lua vim.g.start_time_1 = os.clock()
  unlet a:entry.level

  let l:key = ''
  let l:pos = matchend(a:entry.body, '^\s*')
  while l:pos >= 0
    if empty(l:key)
      let [l:key, l:pos] = cmp_vimtex#get_key(a:entry.body, l:pos)
    else
      let [l:value, l:pos] = cmp_vimtex#get_value(a:entry.body, l:pos, a:strings)
      let a:entry[l:key] = l:value
      let l:key = ''
    endif
  endwhile

  unlet a:entry.body
  lua vim.g.end_time_1 = os.clock()
  lua vim.g.time_1 = (vim.g.end_time_1 - vim.g.start_time_1)
  return a:entry
endfunction

function! cmp_vimtex#get_key(body, head) abort " {{{1
  " Parse the key part of a bib entry tag.
  " Assumption: a:body is left trimmed and either empty or starts with a key.
  " Returncmp_vimtex# The key and the remaining part of the entry body.

  let l:matches = matchlist(a:body, '^\v([-_:0-9a-zA-Z]+)\s*\=\s*', a:head)
  return empty(l:matches)
        \ ? ['', -1]
        \ : [tolower(l:matches[1]), a:head + strlen(l:matches[0])]
endfunction

function! cmp_vimtex#get_value(body, head, strings) abort " {{{1
  " Parse the value part of a bib entry tag, until separating comma or end.
  " Assumption: a:body is left trimmed and either empty or starts with a value.
  " Returncmp_vimtex# The value and the remaining part of the entry body.
  "
  " A bib entry value is either
  " 1. A number.
  " 2. A concatenation (with #s) of double quoted strings, curlied strings,
  "    and/or bibvariables,
  "
  if a:body[a:head] =~# '\d'
    let l:value = matchstr(a:body, '^\d\+', a:head)
    let l:head = matchend(a:body, '^\s*,\s*', a:head + len(l:value))
    return [l:value, l:head]
  else
    return cmp_vimtex#get_value_string(a:body, a:head, a:strings)
  endif

  return ['cmp_vimtex#get_value failed', -1]
endfunction

function! cmp_vimtex#get_value_string(body, head, strings) abort " {{{1
  if a:body[a:head] ==# '{'
    let l:sum = 1
    let l:i1 = a:head + 1
    let l:i0 = l:i1

    while l:sum > 0
      let [l:match, l:_, l:i1] = matchstrpos(a:body, '[{}]', l:i1)
      if l:i1 < 0 | break | endif

      let l:i0 = l:i1
      let l:sum += l:match ==# '{' ? 1 : -1
    endwhile

    let l:value = a:body[a:head+1:l:i0-2]
    let l:head = matchend(a:body, '^\s*', l:i0)
  elseif a:body[a:head] ==# '"'
    let l:index = match(a:body, '\\\@<!"', a:head+1)
    if l:index < 0
      return ['cmp_vimtex#get_value_string failed', '']
    endif

    let l:value = a:body[a:head+1:l:index-1]
    let l:head = matchend(a:body, '^\s*', l:index+1)
    return [l:value, l:head]
  elseif a:body[a:head:] =~# '^\w'
    let l:value = matchstr(a:body, '^\w\+', a:head)
    let l:head = matchend(a:body, '^\s*', a:head + strlen(l:value))
    let l:value = get(a:strings, l:value, '@(' . l:value . ')')
  else
    let l:head = a:head
  endif

  if a:body[l:head] ==# '#'
    let l:head = matchend(a:body, '^\s*', l:head + 1)
    let [l:vadd, l:head] = cmp_vimtex#get_value_string(a:body, l:head, a:strings)
    let l:value .= l:vadd
  endif

  return [l:value, matchend(a:body, '^,\s*', l:head)]
endfunction

function! cmp_vimtex#count(container, item) abort " {{{1
  " Necessary because in old Vim versions, count() does not work for strings
  try
    let l:count = count(a:container, a:item)
  catch /E712/
    let l:count = count(split(a:container, '\zs'), a:item)
  endtry

  return l:count
endfunction
