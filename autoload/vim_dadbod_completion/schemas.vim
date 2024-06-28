let s:base_column_query = 'SELECT table_name, column_name FROM `INFORMATION_SCHEMA`.COLUMNS'
let s:query = s:base_column_query.' ORDER BY column_name ASC'
let s:schema_query = 'SELECT table_schema, table_name FROM `INFORMATION_SCHEMA`.TABLES GROUP BY table_schema, table_name'
let s:count_query = 'SELECT COUNT(*) AS total FROM `INFORMATION_SCHEMA`.COLUMNS'
let s:table_column_query = s:base_column_query.' WHERE table_name="{db_tbl_name}"'
let s:reserved_words = vim_dadbod_completion#reserved_keywords#get_as_dict()
let s:quote_rules = {
      \ 'camelcase': {val -> val =~# '[A-Z]' && val =~# '[a-z]'},
      \ 'space': {val -> val =~# '\s'},
      \ 'reserved_word': {val -> has_key(s:reserved_words, toupper(val))}
      \ }

function! s:map_and_filter(delimiter, list) abort
  return filter(
        \ map(a:list, { _, table -> map(split(table, a:delimiter), 'trim(v:val)') }),
        \ 'len(v:val) ==? 2'
        \ )
endfunction

function! s:should_quote(rules, val) abort
  if empty(trim(a:val))
    return 0
  endif

  let do_quote = 0

  for rule in a:rules
    let do_quote = s:quote_rules[rule](a:val)
    if do_quote
      break
    endif
  endfor

  return do_quote
endfunction

function! s:count_parser(index, result) abort
  return str2nr(get(a:result, a:index, 0))
endfunction

let s:bigquery = {
      \ 'args': ['query', '--use_legacy_sql=false'],
      \ 'column_query': s:query,
      \ 'count_column_query': s:count_query,
      \ 'table_column_query': {table -> substitute(s:table_column_query, '{db_tbl_name}', table, '')},
      \ 'functions_query': "SELECT routine_name FROM `INFORMATION_SCHEMA`.ROUTINES WHERE routine_type='FUNCTION'",
      \ 'functions_parser': {list->list[1:-4]},
      \ 'schemas_query': s:schema_query,
      \ 'schemas_parser': function('s:map_and_filter', ['|']),
      \ 'quote': ['`', '`'],
      \ 'should_quote': function('s:should_quote', [['camelcase', 'reserved_word', 'space']]),
      \ 'column_parser': function('s:map_and_filter', ['|']),
      \ 'count_parser': function('s:count_parser', [1])
      \ }

let s:schemas = {
      \ 'bigquery': s:bigquery,
      \ 'postgres': s:postgres,
      \ 'postgresql': s:postgres,
      \ 'mysql': s:mysql,
      \ 'mariadb': s:mysql,
      \ 'oracle': s:oracle,
      \ 'sqlite': {
      \   'args': ['-list'],
      \   'column_query': "SELECT m.name AS table_name, ii.name AS column_name FROM sqlite_schema AS m, pragma_table_list(m.name) AS il, pragma_table_info(il.name) AS ii WHERE m.type='table' ORDER BY column_name ASC;",
      \   'count_column_query': "SELECT count(*) AS total FROM sqlite_schema AS m, pragma_table_list(m.name) AS il, pragma_table_info(il.name) AS ii WHERE m.type='table';",
      \   'table_column_query': {table -> substitute("SELECT m.name AS table_name, ii.name AS column_name FROM sqlite_schema AS m, pragma_table_list(m.name) AS il, pragma_table_info(il.name) AS ii WHERE m.type='table' AND table_name={db_tbl_name};", '{db_tbl_name}', "'".table."'", '')},
      \   'quote': ['"', '"'],
      \   'should_quote': function('s:should_quote', [['reserved_word', 'space']]),
      \   'column_parser': function('s:map_and_filter', ['|']),
      \   'count_parser': function('s:count_parser', [1]),
      \ },
      \ 'sqlserver': {
      \   'args': ['-h-1', '-W', '-s', '|', '-Q'],
      \   'column_query': s:query,
      \   'count_column_query': s:count_query,
      \   'table_column_query': {table -> substitute(s:table_column_query, '{db_tbl_name}', "'".table."'", '')},
      \   'schemas_query': s:schema_query,
      \   'schemas_parser': function('s:map_and_filter', ['|']),
      \   'quote': ['[', ']'],
      \   'should_quote': function('s:should_quote', [['reserved_word', 'space']]),
      \   'column_parser': function('s:map_and_filter', ['|']),
      \   'count_parser': function('s:count_parser', [0])
      \ },
    \ }

function! vim_dadbod_completion#schemas#get(scheme)
  return get(s:schemas, a:scheme, {})
endfunction

function! vim_dadbod_completion#schemas#get_quotes_rgx() abort
  let open = []
  let close = []
  for db in values(s:schemas)
    if index(open, db.quote[0]) <= -1
      call add(open, db.quote[0])
    endif

    if index(close, db.quote[1]) <= -1
      call add(close, db.quote[1])
    endif
  endfor

  return {
        \ 'open': escape(join(open, '\|'), '[]'),
        \ 'close': escape(join(close, '\|'), '[]')
        \ }
endfunction
