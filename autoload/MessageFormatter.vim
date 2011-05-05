" MessageFormatter.vim: an autoload plugin to format strings with parameters
" By: Salman Halim
"
" Version 6.0:
"
" Added an option: g:MessageFormatter_autoAddJumpToEnd; if this is 1 (the default) and if a parameter contains !jump! directives, another !jump! is added to the
" end to allow the user to quickly continue typing beyond the template. See :help g:MessageFormatter_autoAddJumpToEnd
"
" Version 5.5:
"
" Fixed bug in default processing.
"
" Improved help and added examples to help (:help MessageFormatter_Examples).
"
" Version 5.0:
"
" Added a default value mechanism: if a template variable is defined like this:
"
" {def John::firstName}
"
" then, during expansion, if an empty value is passed in for firstName, "John" will be used instead. This value can be recursive and may contain other
" parameters, as before. (Including other "def" expansions.)
"
" Also, parameters with default values may be left out to have their default value used; see :help MessageFormatter_def for more details.
"
" Version 4.5:
"
" Bug fixes, mostly, though added one more option:
"
" g:MessageFormatter_formatCurrentLineAsFallback (default 1): if attempting to format a template via the <Plug>FormatCurrentTemplate mapping when not actually
" in a template, will fall back to formatting just the current line as an ad-hoc template if this is 1. If 0, will give an error message instead.
"
" Version 4.0:
"
" Changed the interface, adding the ability to expand templates while typing.
"
" Commands:
" Addglobaltemplate: adds a template pattern useful everywhere
" Addlocaltemplate: adds a template pattern for the current buffer only (might be used from an ftplugin)
"
" Listglobaltemplates: simple list of global templates
" Listlocaltemplates: simple list of local (buffer-specific) templates
"
" Formatvisualrange: expands a range of text lines (in the buffer) containing default values. Best called from mappings rather than directly.
"
" Patterns:
"
" The examples (loaded unless g:MessageFormatter_createDefaultTemplates is set to 0 in your vimrc) define some fairly complex templates. Dissecting one:
"
" Addglobaltemplate var {::type} {::c_var} = new {eval {p_type} =~# '^List' ? 'Array{type}' : {p_type} =~# '^Map' ? 'Hash{type}' : {p_type}::instanceType}();
"
" Template name: var
" Number of arguments: 2 ('type' and 'var'); defined by the {::...} format
"
" Template particulars:
"
" {::type}: get value for 'type' and use as is.
" {::c_var}: get value for 'var' and camel-case it.
" {eval {p_type} =~# '^List' ? 'Array{type}' : {p_type} =~# '^Map' ? 'Hash{type}' : {p_type}::instanceType}: variable 'instanceType' is given an "eval" value,
" which is evaluated as a ternary expression:
"
" {p_type} =~# '^List' ? 'Array{type}' : {p_type} =~# '^Map' ? 'Hash{type}' : {p_type}
"
" If the value, wrapped in single quotes (p_type; suitable for use in a Vim expression), starts with List, instantiate it as an ArrayList; if it starts with
" Map, instantiate it has a HashMap; otherwise, use as is. (List and Map are interfaces in Java and can't be instantiated directly).
"
" This allows you to to type
"
" var List<String> names
"
" and hit the hotkey for <Plug>PlaceTemplateForLine (see the mapping for more details) in insert mode to get
"
" List<String> names = new ArrayList<String>();
"
" Another one:
"
" Addglobaltemplate do do\n{\n|\n} while ( !jump! );
"
" Type do and hit the mapping for <Plug>PlaceTemplateInText and it will replace the word with the expansion in place (can be used with 'var', also), moving the
" cursor to the | and replacing the !jump! with jump characters.
"
" If the <Plug>PlaceTemplateInText mapping is used for expansions such as 'var'' above, the cursor goes to the first {::...} variable and all others change to
" {!jump!::...} so a jump hotkey (assuming there is a jumper plugin installed) will move from one to the next. Once the values have been entered, hit the hotkey
" for <Plug>FormatCurrentTemplate (insert or normal mode) and the template will be expanded inline. The plugin remembers the last template placed, so if a
" second template is placed before the first is expanded, the first will be forgotten.
"
" Notes:

" - Patterns replace all \n instances (backslashes followed by 'n') with newlines and all !jump! occurrences with the value of MessageFormatter_jumpMarker.
"
" - Template definitions are searched locally and then globally, thus a local template with the same name will be used instead of the global one.
"
" Mappings:
"
" The following mappings have been defined (shown here with default values); if you set up the <Plug> mappings yourself, these won't be assigned:
"
" imap <c-del>          <Plug>FormatCurrentTemplate: expands the last inline template placed by <Plug>PlaceTemplateInText, as long as the cursor is within the
" range of lines placed by the mapping. The cursor is placed at the end of the expansion, in insert mode, so more typing can be accomplished.
"
" nmap <c-del>          <Plug>FormatCurrentTemplate: same as the imap version, but from normal mode, except that the cursor doesn't move and stays in normal
" mode.
"
" imap <Leader><Leader> <Plug>PlaceTemplateInText: given a template name as the word on the cursor, replaces it with the expansion; if the expansion isn't
" found, it's just replaced with itself, wrapped in exclamation marks (so, 'adsfasdfadsf' becomes '!adsfasdfadsf!'). Hit undo to get back to the word.
"
" imap ``               <Plug>PlaceTemplateForLine: given a line containing nothing but a template name and parameter values, will replace the line with the
" fully expanded template. The arguments should be separated by MessageFormatter_parameterSeparator or, if the arguments are single words (themselves contain no
" whitespace) they may be separated by a single space to ease data entry. If a truly blank value is desired for any of the parameters, use
" MessageFormatter_blankParameter as the value.
"
" nmap <c-del><c-del>   <Plug>FormatOneLine
"
" nmap <c-s-del>        <Plug>FormatOpModeTemplate
"
" Note: <Plug>PlaceTemplateInText looks only at the current word so is useful for templates that are meant to be used as part of a whole line (look at
" 'safetern' in the examples), although it can be used for multi-line templates, also. <Plug>PlaceTemplateForLine looks at the entire line because it expects
" all the parameter values to be provided up front.
"
" Options (with default values):
"
" g:MessageFormatter_blankParameter (default '`'--back-tick): if a value is to be blank, use this in its place to indicate same
"
" g:MessageFormatter_parameterSeparator (default '\s\{2,}'--two or more whitespace characters): separator for multiple arguments; maybe change it to a single
" tab or another regular expression such as :: or something
"
" g:MessageFormatter_jumpMarker (default '«»'): replaces !jump! values in expansions with this expression as well as, in inline parameters, for all but the
" first parameter (the cursor is placed on the first one).
"
" As always, they may be set on a per buffer basis (with b: versions), per window or per tab because my GetVar script is required for this to work.
"
" New modifiers types:
"
" m: expects a number immediately after and repeats the text the specified number of times; no number is the same as 1. So, {m3_name} converts 'John' to
" 'JohnJohnJohn' and {*::m30_v} becomes ******************************
" p: Wrap result in apostrophes, escaping single apostrophes with doubles (suitable for Vim literal string use); so, {ab'c::p_var} gives 'ab''c' (including the
" quotes)
" q: Wrap result in quotes, escaping inner quotes and backslashes with backslashes; so, {ab"c::q_var} gives "ab\"c" (including the quotes)
" s: If the result is empty, nothing; otherwise, wrap it in spaces. So, '0' becomes ' 0 ', but '' remains ''
"
"
" Version 3.5:
"
" Added a command version of FormatContainedMessage called Formatcontainedmessage that passes everything on the command-line as-is to the function and echoes
" the result.
"
" Added a new default value type:
"
" If the default value for for a parameter (passed to FormatContainedMessage) is "ask", it defaults to asking the user (via an input). If the value is anything
" followed by "ask", it will use that as the default value for the input.
"
" Examples:
" "
" {ask::first name} will display an input prompt asking, "Enter value for first name".
"
" {ask Smith::last name} will display an input prompt asking "Enter value for last name", but will offer "Smith" as the default value (just press enter to
" accept).
"
" As always, recursion is supported, so
"
" My name is {ask {ask John::first name} {ask Smith::last name}::full name} (family name is {last name}).
"
" Will first prompt for the first name, offering "John" as the default, then for the last name, offering "Smith" as the default and, finally, for the full name,
" offering the entered first and last name together as the default ("John Smith" by default) before displaying the formatted message.
"
" Version 3.0:
"
" Fairly big changes. RELIES UPON MY GetVar.vim script now.
"
" New formatting parameter:
"
" n: non-displayed value. The return value is suppressed--useful for adding a value to the cache to be used later.
"
" New functions:
"
" FormatContainedMessage: Works like MessageFormatter#FormatMessage except that it's always recursive and that its original text string can contain default
" values for the parameters (so the second parameter is optional); for example,
"
" echo FormatContainedMessage( 'My first name is {John::first name} and my full name is {{first name} Smith::full name}; how many letters in {u_full name}?' )
"
" Gives
"
" My first name is John and my full name is John Smith; how many letters in JOHN SMITH?
"
" This can be recursive (look at "full name" and can contain more default values, such as starting things with "eval " to have them evaluated. To force an empty
" string, use {::name} (just {name} assumes that the value will be specified elsewhere).
"
" Some commands and functions to allow the reuse of parameters:
"
" FormatMessage: takes a string and returns a formatted value, using previously specified parameters through:
"
" Formatmessage and Formatmessagerecursive: command versions that call FormatMessage; process whatever is typed.
"
" Addformatparameter: adds whatever you type as is (may be recursive) as a list parameter.
"
" Adddictionaryformatparameter: adds whatever you type as is, with the first word being the name of the parameter and the rest of the arguments the value.
"
" Showparameters: Displays the list of specified parameters.
"
" Resetformatparameters: Removes the list of parameters currently specified.
"
" Version 2.0:
"
" Added new formatting modifier:
"
" e: Escapes out quotation marks (") and backslashes, leaving the value suitable for placing in quotes. For example, {e_fName} where fName is Jo\nhn results in
" Jo\\nhn.
"
" If an expansion parameter starts with "eval ", the rest of the value is evaluated and the return value used as the actual parameter value. If recursion is on,
" that value may contain further parameters.
"
" Example:
"
" echo MessageFormatter#FormatMessage('public static final {type} {C_variable} = {value};', {'type':'eval input("Type for {variable}: ", "String")', 'variable':'eval input("Variable name: ")', 'value':'eval input("Value: ", "\"{C_variable}\"")'}, 1)
"
" Bear in mind that 'type' and 'value' both use the parameter 'variable'. If 'variable' were to refer to either of these, you'd have circular recursion. There
" is no check in place for that; you'd just end up with a stack overflow.
"
" Note, also, that the expression is evaluated only once. After that, its value is stored on the cache--this allows eval parameters to refer to other eval
" parameters (only useful if recursion is on).
"
" Version 1.5:
"
" Added a cache so repeated expansions of the same variable can be looked up rather than computed (potentially much faster, especially when recursion is on).
"
" Original version (1.0):
"
" Given a pattern string and a set of values, replaces the parameters in the pattern with the specified values. The values may be either a Dictionary or a List,
" and the expansion can be done recursively or just once, as in the example below.
"
" Example (note the 1 at the end, indicating recursion as fullName is defined as fName and lName):
"
" echo MessageFormatter#FormatMessage( "My name is {fullName} (first name '{fName}', last name '{lName}').", { 'fName': 'john', 'lName': 'smith', 'fullName': '{t_fName} {t_lName}' }, 1 )
"
" Echoes (note how fullName gets further expanded): My name is John Smith (first name 'john', last name 'smith').
"
" Same example, with a 0 at the end (or nothing, as the recursion parameter is optional):
"
" Echoes (note how fullName is not expanded recursively): My name is {t_fName} {t_lName} (first name 'john', last name 'smith').
"
" Same (recursive) example using a List instead of a Dictionary:
"
" echo MessageFormatter#FormatMessage( "My name is {2} (first name '{0}', last name '{1}').", [ 'john', 'smith', '{t_0} {t_1}' ], 1 )
"
" Note: To use an actual '{' or '}', escape it with a backslash.
"
" Observe how some of the parameters start with t_ before the actual name. There are a number of formatting parameters:
"
" a (optional): as is
" l: lower case
" u: upper case
" f: first letter capitalized only
" t: title case the entire string
" c: camel case: converts 'an interesting phrase' to 'anInterestingPhrase'
" C: constant mode: converts 'anInterestingPhrase' or 'an interesting phrase' to 'AN_INTERESTING_PHRASE'
" w: from 'anInterestingPhrase' or 'AN_INTERESTING_PHRASE' to 'an intersting phrase'
"
" Both the parameters AND the formatting directives are case-sensitive. If multiple formatting parameters are specified, they will be applied in the order
" supplied. For example {c_val} where 'val' is 'some variable' results in 'someVariable'. However, {cf_val} gives 'SomeVariable' because the following 'f'
" capitalizes the first letter of the result from 'c' (camel case).
"
" Installation: Unzip into a directory in your &runtimepath.
"
" Other examples
"
" let g:test="public void set{f_1}( {0} val )\n".
" \ "\\{\n".
" \ "m_{1} = val;\n".
" \ "\\}\n".
" \ "\n".
" \ "public {0} get{f_1}()\n".
" \ "\\{\n".
" \ "return m_{1};\n".
" \ "\\}"
" let g:parameters=[ 'String', 'test' ]

" let g:message = "{0}, {1}, \\{{2},\\} {3} {0} {0} {2}"
" let g:parameters = [ "john", "smith (plus {u_0})", "{1}, {0} {t_3}", '\{{0} {1}\}' ]
"
" let g:test="/**\n" .
"       \ "Constant value for '{f_0}'.\n" .
"       \ "/\n" .
"       \ "public static final String {C_0} = \"{c_0}\";"


" Case in directives is maintained. Thus, {fname} is NOT the same as {FNAME}.
"
" This is especially important during recursion.

" Modifiers may be combined: {wt_test}--where 'test' maps to 'SOME_CONSTANT_TEXT'--will result in 'Some Constant Text'.
"
" The moifiers are executed in the order received.
"
" a (optional): as is
" c: camel case: converts 'an interesting phrase' to 'anInterestingPhrase'
" C: constant mode: converts 'anInterestingPhrase' or 'an interesting phrase' to 'AN_INTERESTING_PHRASE'
" e: Escapes out quotation marks (") and backslashes, leaving the value suitable for placing in quotes
" f: first letter capitalized only
" l: lower case
" m: expects a number immediately after and repeats the text the specified number of times; no number is the same as 1. So, {m3_name} converts 'John' to
" 'JohnJohnJohn' and {*::m30_v} becomes ******************************
" n: Suppresses output; useful for adding the value to cache without actually displaying it
" p: Wrap result in apostrophes, escaping single apostrophes with doubles (suitable for Vim literal string use)
" q: Wrap result in quotes, escaping inner quotes and backslashes with backslashes
" s: If the result is empty, nothing; otherwise, wrap it in spaces. So, '0' becomes ' 0 ', but '' remains ''
" t: title case the entire string
" u: upper case
" w: from 'anInterestingPhrase' or 'AN_INTERESTING_PHRASE' to 'an intersting phrase'
function! MessageFormatter#ModifyValue( value, modifiers )
  let result = a:value
  let i      = 0

  while ( i < len( a:modifiers ) )
    let modifier = a:modifiers[ i ]

    if ( modifier ==# '' || modifier ==# 'a' )
      let result = result
    elseif ( modifier ==# 'l' )
      let result = tolower( result )
    elseif ( modifier ==# 'u' )
      let result = toupper( result )
    elseif ( modifier ==# 'f' )
      let result = substitute( result, '^.', '\U&', '' )
    elseif ( modifier ==# 't' )
      let result = substitute( result, '\(\<.\)\(\S*\)', '\u\1\L\2', 'g' )
    elseif ( modifier ==# 'c' )
      " If there are no spaces or underscores, it's probably already camel case, so leave it alone.
      if ( match( result, '[_ ]' ) >= 0 )
        let result = substitute( tolower( result ), '[_ ]\([a-z]\)', '\u\1', 'g' )
      endif
    elseif ( modifier ==# 'C' )
      let result = toupper( substitute( substitute( result, '\C\([^A-Z]\)\([A-Z]\)', '\1_\2', 'g' ), '[[:space:]_]\+', '_', 'g' ) )
    elseif ( modifier ==# 'w' )
      let result = tolower( substitute( substitute( result, '\C\([^A-Z]\)\([A-Z]\)', '\1 \2', 'g' ), '_', '', 'g' ) )
    elseif ( modifier ==# 'e' )
      let result = escape( result, '"\' )
    elseif ( modifier ==# 'p' )
      let result = "'" . substitute( result, "'", "''", "g" ) . "'"
    elseif ( modifier ==# 'q' )
      let result = '"' . escape( result, '"\' ) . '"'
    elseif ( modifier ==# 'n' )
      let result = ''
    elseif ( modifier ==# 's' )
      let result = result == '' ? result : ' ' . result . ' '
    elseif ( modifier ==# 'm' )
      let multiplier = ''

      while ( a:modifiers[ i + 1 ] =~ '\d' )
        let multiplier .= a:modifiers[ i + 1 ]

        let i += 1
      endwhile

      let result = repeat( result, multiplier == '' ? 1 : multiplier )
    else
      " Unrecognized modifier.
      let result = '!' . modifier . '!' . result
    endif

    let i += 1
  endwhile

  return result
endfunction

function! MessageFormatter#ProcessOnce( message, parameters, recursive )
  let isDictionary = type( a:parameters ) == 4

  let parameterPattern = '\C{\%(\([^_}]*\)_\)\=\([^}]\+\)}'

  let result     = ''
  let startIndex = 0
  let matchIndex = match( a:message, parameterPattern, startIndex )

  while ( matchIndex >= 0 )
    let [ expansionDirective, modifiers, parameter; dummy2 ] = matchlist( a:message, parameterPattern, startIndex )

    if ( matchIndex > 0 )
      let result .= a:message[ startIndex : matchIndex - 1 ]
    endif

    " If it's a dictionary, it needs to have the key; otherwise (it's a list), it needs to have at least as many items as the parameter. If not, just return the
    " parameter unexpanded.
    let keyExists      = 0
    let parameterValue = ''
    let gotValue       = 0

    " If it's in the cache already, no need to look among the parameters for a value.
    if ( has_key( s:parameterCache, parameter ) )
      let parameterValue = s:parameterCache[ parameter ]

      let gotValue = 1
    else
      if ( isDictionary )
        let keyExists = has_key( a:parameters, parameter )
      else
        let keyExists = len( a:parameters ) > parameter
      endif

      if ( keyExists )
        let parameterValue = a:parameters[ parameter ]

        if ( a:recursive )
          let parameterValue = MessageFormatter#FormatMessageInternal( parameterValue, a:parameters, 1 )
        endif

        if ( parameterValue =~# '^eval ' )
          let parameterValue = string( eval( substitute( parameterValue, '^eval ', '', '' ) ) )
          let parameterValue = substitute( parameterValue, '^''\=\(.\{-}\)''\=$', '\1', 'g' )
        elseif ( parameterValue =~# 'ask\%( \|$\)' )
          let parameterValue = input( "Set '" . parameter . "' to: ", substitute( parameterValue, '^ask \=', '', '' ) )
        endif

        let s:parameterCache[ parameter ] = parameterValue

        let gotValue = 1
      endif
    endif

    if ( gotValue == 1 )
      let result .= MessageFormatter#ModifyValue( parameterValue, modifiers )
    else
      let result .= expansionDirective
    endif

    let startIndex = matchend( a:message, parameterPattern, startIndex )
    let matchIndex = match( a:message, parameterPattern, startIndex )
  endwhile

  let result .= a:message[ startIndex : ]

  return result
endfunction

function! MessageFormatter#FormatMessageInternal( message, parameters, recursive )
  let expandedMessage = substitute( a:message, '\\{', '_OPEN_BRACE_', 'g' )
  let expandedMessage = substitute( expandedMessage, '\\}', '_CLOSE_BRACE_', 'g' )

  let result = MessageFormatter#ProcessOnce( expandedMessage, a:parameters, a:recursive )

  let result = substitute( result, '_OPEN_BRACE_', '{', 'g' )
  let result = substitute( result, '_CLOSE_BRACE_', '}', 'g' )

  return result
endfunction

let s:parameterCache = {}

function! MessageFormatter#ResetParameterCache()
  let s:parameterCache = {}
endfunction

" If not recursive, start from beginning, get parameter, expand, continue.
"
" If recursive, repeat until no change.
function! MessageFormatter#FormatMessage( message, parameters, ... )
  let recursive = exists( "a:1" ) && a:1 == 1

  if ( !exists( "a:2" ) || a:2 != 1 )
    call MessageFormatter#ResetParameterCache()
  endif

  return MessageFormatter#FormatMessageInternal( a:message, a:parameters, recursive )
endfunction

function! MessageFormatter#FormatOpModeTemplate( type, ... )
  execute "'[,']Formatvisualrange"
endfunction

function! MessageFormatter#FormatCurrentTemplate( endInInsertMode )
  let error = ''

  if ( !exists( "b:MessageFormatter_snippetStart" ) || !exists( "b:MessageFormatter_snippetEnd" ) )
    let error = "Not in a formally defined template."
  else
    let currentLine = line( '.' )

    if ( currentLine >= b:MessageFormatter_snippetStart && currentLine <= b:MessageFormatter_snippetEnd )
      " Break the undo chain.
      execute "normal! i\<c-g>u"

      execute b:MessageFormatter_snippetStart . ',' . b:MessageFormatter_snippetEnd . 'Formatvisualrange'

      " Move to the end of the snippet and start insert mode so the user can continue.
      "
      " SALMAN: Look for {|} or something and move the cursor there instead?
      if ( a:endInInsertMode )
        execute b:MessageFormatter_snippetEnd

        startinsert!
      endif

      return
    endif
  endif

  if ( error == '' )
    let error = "Not inside the last used template."
  endif

  if ( GetVar#GetVar( "MessageFormatter_formatCurrentLineAsFallback" ) == 1 )
    echo error . ' Falling back to current line.'
    Formatvisualrange
  else
    echo error
  endif
endfunction

let s:escapeOpenBrace = '_OPEN_DIRECTIVE_BRACE_'
let s:escapeCloseBrace = '_CLOSE_DIRECTIVE_BRACE_'

" The last parameter, if 0 or not provided, doesn't break the undo chain.
function! MessageFormatter#FormatVisualRange( line1, line2, ... )
  " Break the undo chain unless asked not to.
  if ( !exists( "a:1" ) || a:1 == 1 )
    execute "normal! i\<c-g>u"
  endif

  call MessageFormatter#ResetParameterCache()

  let s:MessageFormatter_parameters = {}
  let currentLine                   = a:line1
  let firstLine                     = 1

  let directiveExpression       = '{\(\%(\\[{}]\|[^{}]\)\{-}\)::\%(\(\%(\\[{}]\|[^{}]\)\{-}\)_\)\=\(\%(\\[{}]\|[^{}]\)\{-}\)}'
  let simpleDirectiveExpression = '{\(\%(\\[{}]\|[^{}]\)\+\)}'

  " Extract the variable values from the lines, leaving the lines containing only variable names.
  while ( currentLine <= a:line2 )
    let originalLine = getline( currentLine )
    let newLine      = originalLine

    if ( newLine =~ directiveExpression )
      let newLine    = ''
      let startIndex = 0
      let matchIndex = match( originalLine, simpleDirectiveExpression, startIndex )

      while ( matchIndex >= 0 )
        let [ original, variable; remainder ] = matchlist( originalLine, simpleDirectiveExpression, startIndex )

        if ( matchIndex > 0 )
          let newLine .= originalLine[ startIndex : matchIndex - 1 ]
        endif

        if ( variable !~ '::' )
          let newLine .= s:escapeOpenBrace . variable . s:escapeCloseBrace
        else
          let newLine .= original
        endif

        let startIndex = matchend( originalLine, simpleDirectiveExpression, startIndex )
        let matchIndex = match( originalLine, simpleDirectiveExpression, startIndex )
      endwhile

      let newLine .= originalLine[ startIndex : ]
    endif

    while ( newLine =~ directiveExpression )
      let [ original, value, modifiers, variable; remainder ] = matchlist( newLine, directiveExpression )

      let value = substitute( value, s:escapeOpenBrace, '{', 'g' )
      let value = substitute( value, s:escapeCloseBrace, '}', 'g' )

      let s:MessageFormatter_parameters[ variable ] = value == GetVar#GetVar( "MessageFormatter_jumpMarker" ) || value == GetVar#GetVar( "MessageFormatter_blankParameter" ) ? '' : value
      " let s:MessageFormatter_parameters[ variable ] = value

      let replacement = modifiers == '' ? '\4' : '\3_\4'
      let newLine     = substitute( newLine, '^\(.\{-}\)' . directiveExpression . '\(.*\)$', '\1_OPEN_DIRECTIVE_BRACE_' . replacement . '_CLOSE_DIRECTIVE_BRACE_\5', '' )
    endwhile

    let newLine = substitute( newLine, s:escapeOpenBrace, '{', 'g' )
    let newLine = substitute( newLine, s:escapeCloseBrace, '}', 'g' )

    if ( newLine !=# originalLine )
      if ( firstLine == 1 )
        let firstLine = 0
      else
        undojoin
      endif

      call setline( currentLine, newLine )
    endif

    let currentLine += 1
  endwhile

  " Process the lines.
  let currentLine = a:line1

  while ( currentLine <= a:line2 )
    let thisLine = getline( currentLine )

    " Only process lines with directives (or what appear to be directives) on them.
    if ( thisLine =~ '{.\{-}}' )
      let newLine = MessageFormatter#FormatMessage( thisLine, s:MessageFormatter_parameters, 1, 1 )

      if ( newLine !=# thisLine )
        undojoin

        call setline( currentLine, newLine )
      endif
    endif

    let currentLine += 1
  endwhile
endfunction
