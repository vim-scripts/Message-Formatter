if ( exists( "g:MessageFormatter_loaded" || &compatible || version < 703 ) )
  finish
endif

let g:MessageFormatter_loaded = 1


if ( !exists( "g:MessageFormatter_blankParameter" ) )
  let g:MessageFormatter_blankParameter = '`'
endif

if ( !exists( "g:MessageFormatter_parameterSeparator" ) )
  let g:MessageFormatter_parameterSeparator = '  '
endif

if ( !exists( "g:MessageFormatter_jumpMarker" ) )
  let g:MessageFormatter_jumpMarker = '��'
endif

if ( !exists( "g:MessageFormatter_formatCurrentLineAsFallback" ) )
  let g:MessageFormatter_formatCurrentLineAsFallback = 1
endif

if ( !exists( "g:MessageFormatter_autoAddJumpToEnd" ) )
  let g:MessageFormatter_autoAddJumpToEnd = 1
endif

if ( !exists( "g:MessageFormatter_highlightDirectives" ) )
  let g:MessageFormatter_highlightDirectives = 1
endif

if ( !exists( "g:MessageFormatter_highlightDirectivesLink" ) )
  let g:MessageFormatter_highlightDirectivesLink = 'Error'
endif

if ( !exists( "g:MessageFormatter_moveArgumentsToStart" ) )
  let g:MessageFormatter_moveArgumentsToStart = 1
endif

if ( !exists( "g:MessageFormatter_highlightDirectiveModifiersLink" ) )
  let g:MessageFormatter_highlightDirectiveModifiersLink = 'Constant'
endif

function! FormatMessage( message, recursive )
  if ( !exists( "g:MessageFormatter_parameters" ) )
    return a:message
  endif

  return MessageFormatter#FormatMessage( a:message, g:MessageFormatter_parameters, a:recursive )
endfunction

function! AddFormatParameters( ... )
  call GetVar#Allocate( "g:MessageFormatter_parameters", [] )

  " It's a List, so just append the parameters.
  if ( type( g:MessageFormatter_parameters ) == 3 )
    let g:MessageFormatter_parameters += a:000
  else
    let index = 0

    " Dictionary
    for parameter in a:000
      " Locate the next unused numerical key value.
      while ( has_key( g:MessageFormatter_parameters, index ) )
        let index += 1
      endwhile

      let g:MessageFormatter_parameters[ index ] = parameter

      let index += 1
    endfor
  endif
endfunction

function! AddDictionaryFormatParameter( arg )
  let [ dummy, key, value; rest ] = matchlist( a:arg, '^\(\S\+\)\s\+\(.*\)$' )

  call GetVar#Allocate( "g:MessageFormatter_parameters", {} )

  " List; can't add.
  if ( type( g:MessageFormatter_parameters ) == 3 )
    echoerr "The parameters are contained a List, not a Dictionary. To just add the parameter as is, use Addformatparameter instead."

    echo "The parameter list: " . string( g:MessageFormatter_parameters )

    return
  endif

  let g:MessageFormatter_parameters[ key ] = value
endfunction

function! IncrementCurrentPointer()
  let s:MessageFormatter_currentPointer += 1
endfunction

function! ExtractVariableName()
  let s:variableProcessedCorrectly = 0

  let valueFinished     = 0
  let modifiersFinished = 0
  let value             = ''
  let modifiers         = ''
  let variableName      = ''

  while ( s:MessageFormatter_currentPointer < len( s:MessageFormatter_text ) )
    let char = s:MessageFormatter_text[ s:MessageFormatter_currentPointer ]

    call IncrementCurrentPointer()

    if ( char == '\' )
      " Escaped character; put it in as is (still escaped).
      let value .= char . s:MessageFormatter_text[ s:MessageFormatter_currentPointer ]

      call IncrementCurrentPointer()
    elseif ( char == '{' )
      " Process inner variable recursively.
      let value .= '{' . ExtractVariableName() . ( s:variableProcessedCorrectly ? '}' : '' )

      let s:variableProcessedCorrectly = 0
    elseif ( char == ':' )
      " Value/variable name separator (::).
      if ( s:MessageFormatter_text[ s:MessageFormatter_currentPointer ] == ':' )
        let valueFinished = 1

        call IncrementCurrentPointer()
      else
        let value .= char
      endif
    elseif ( char == '}' )
      let s:variableProcessedCorrectly = 1

      break
    elseif ( valueFinished )
      if ( modifiersFinished )
        let variableName .= char
      elseif ( char == '_' )
        let modifiersFinished = 1
      else
        let modifiers .= char
      endif
    else
      let value .= char
    endif
  endwhile

  if ( !valueFinished )
    let [ dummy, modifiers, variableName; remainder ] = matchlist( value, '\([_]*\)_\=\(.*\)' )
    let value                                         = ''
  elseif ( !modifiersFinished )
    let variableName = modifiers
    let modifiers = ''
  endif

  " If they passed in an empty value on purpose, we should honour it.
  if ( value != '' || valueFinished )
    let s:MessageFormatter_parameters[ variableName ] = value
  endif

  return ( modifiers == '' ? '' : modifiers . '_' ) . variableName
endfunction

function! FormatContainedMessage( text, ... )
  let s:MessageFormatter_text           = a:text
  let s:MessageFormatter_parameters     = exists( "a:2" ) && type( a:2 ) == 4 ? a:2 : {}
  let s:MessageFormatter_currentPointer = 0

  let messageToFormat = ExtractVariableName()

  return MessageFormatter#FormatMessage( messageToFormat, s:MessageFormatter_parameters, 1, exists( "a:1" ) && a:1 == 1 )
endfunction

function! PlaceTemplateInText( ... )
  " Break the undo chain so hitting undo gives the user back the word they had typed to launch this mapping.
  execute "normal! i\<c-g>u"

  if ( exists( "a:1" ) )
    let templateName = a:1
  else
    let saveZ = @z

    normal "zciW*

    let templateName = @z

    let @z = saveZ
  endif

  let result = GetTemplateDefinition( templateName )

  let result = ExpandDirectiveValues( result, 'tem' )
  let result = ExpandDirectiveValues( result )
  let result = ConsolidateDuplicateDirectives( result )

  if ( GetVar#GetVar( 'MessageFormatter_moveArgumentsToStart' ) == 1 )
    let args = ''

    while ( result =~ s:inputDirectiveExpression )
      let args .= substitute( result, '.\{-}' . s:inputDirectiveExpression . '.*', '{::n_\2}', '' )
      let result = substitute( result, s:inputDirectiveExpression, '{\1\2}', '' )
    endwhile

    let result = args . result
  endif

  " Make the first one the cursor location.
  " let result = substitute( result, '{::', '{|::', '' )
  " Make the rest placeholders for jumping.
  let result = substitute( result, '{::', '{!jump!::', 'g' )
  " Convert newlines
  let result = substitute( result, '\\n', "\n", 'g' )

  " If the expansion contains jump directives.
  if ( GetVar#GetVar( "MessageFormatter_autoAddJumpToEnd" ) == 1 && result =~# '!jump!' && result !~# '!jump!$' )
    let result .= '!jump!'
  endif

  " Convert jump directives
  let result = substitute( result, '!jump!', GetVar#GetVar( "MessageFormatter_jumpMarker" ), 'g' )

  silent! undojoin

  let savedFo = &fo
  set fo=
  execute 'normal! "_s' . result . "\<esc>"
  let &fo = savedFo

  " Store for automatic expansion later.
  let b:MessageFormatter_snippetStart = line( "'[" )
  let b:MessageFormatter_snippetEnd   = line( "']" )

  call MessageFormatter#EditFirstJumpLocation( b:MessageFormatter_snippetStart, b:MessageFormatter_snippetEnd )
endfunction

" If the second optional argument is provided and the template doesn't exist, return the empty string.
function! GetTemplateDefinition( templateName, ... )
  " First look for a local key and then for a global key.
  let result = ''
  let root   = 'b'
  let hasKey = exists( root . ':MessageFormatter_templates' ) && has_key( {root}:MessageFormatter_templates, a:templateName )

  if ( !hasKey )
    let root   = 'g'
    let hasKey = exists( root . ':MessageFormatter_templates' ) && has_key( {root}:MessageFormatter_templates, a:templateName )
  endif

  if ( hasKey )
    let result = {root}:MessageFormatter_templates[ a:templateName ]
  else
    let result = !exists( "a:1" ) ? '!' . a:templateName . '!' : ''
  endif

  return result
endfunction

let s:openBrace  = '_OPEN_BRACE_'
let s:closeBrace = '_CLOSE_BRACE_'

" echo ExtractInnermostDirective( "public static final {::type} {::C_var} = {def {var}::n_value}{eval '{type}' == 'String' ? {qp_value} : {p_value}::parsedValue};" )
" echo ExtractInnermostDirective( "public static final {::type} {::C_var} = {sub {p_var}, '[aeiou]', '1', 'g'::n_value}{eval '{type}' == 'String' ? {qp_value} : {p_value}::parsedValue};" )
function! ExtractInnermostDirective( line, ... )
  " let directiveExpression  = '\%(sub\|def\) '
  let directiveExpression = '\%(' . ( exists( "a:1" ) ? a:1 : 'def ' ) . '\) '
  let directiveLength     = 4
  let lineLength          = strlen( a:line )
  let directiveDetails    = {}

  let directiveDetails.directive    = ''
  let directiveDetails.startIndex   = -1
  let directiveDetails.endIndex     = -1
  let directiveDetails.defaultValue = ''
  let directiveDetails.modifiers    = ''
  let directiveDetails.variable     = ''

  let value = ''

  let parsingDefault = 0

  let parseDepth     = 0
  let currentPointer = 0

  while ( currentPointer < lineLength )
    let char = a:line[ currentPointer ]

    let currentPointer += 1

    if ( char == '\' )
      " Escaped character; put it in as is (still escaped).
      if ( parsingDefault == 1 )
        let value .= char . a:line[ currentPointer ]
      endif

      let currentPointer += 1
    elseif ( char == '{' )
      let newDirective = 0

      " Might be the start of a default block; the next four characters have to be matched to see if they are "def ". An actual directive would have to be much longer
      " because it has to be at least: {def a::a} (10 characters).
      if ( currentPointer < lineLength - directiveLength )
        let testCharacters = a:line[ currentPointer : currentPointer + directiveLength - 1 ]

        if ( testCharacters =~# directiveExpression )
          let directiveDetails.startIndex = currentPointer - 1
          let directiveDetails.directive  = testCharacters
          let currentPointer             += directiveLength
          let parsingDefault              = 1
          let value                       = ''
          let newDirective                = 1
        endif
      endif

      " Just another directive; if we're inside another default expression, continue collecting characters.
      if ( newDirective == 0 && parsingDefault == 1 )
        let value      .= char
        let parseDepth += 1
      endif
    elseif ( char == '}' )
      if ( parsingDefault == 1 )
        " End of default
        if ( parseDepth == 0 )
          let parsingDefault            = 0
          let directiveDetails.endIndex = currentPointer - 1

          let [ expression, directiveDetails.defaultValue, directiveDetails.modifiers, directiveDetails.variable; remainder ] = matchlist( value, '\(.*\)::\%(\([^_]*\)_\)\=\(.*\)' )

          break
        else
          let value .= char
        endif

        let parseDepth -= 1
      endif
    elseif ( parsingDefault == 1 )
      let value .= char
    endif
  endwhile

  return directiveDetails
endfunction

" Recursive def should work now; for example:
" echo ExpandDirectiveValues( "public static final {::type} {::C_var} = {def {var}::n_value}{eval '{type}' == 'String' ? {qp_value} : {p_value}::parsedValue};" )
function! ExpandDirectiveValues( line, ... )
  let result = a:line

  let blank     = GetVar#GetVar( "MessageFormatter_blankParameter" )
  let directive = exists( "a:1" ) ? a:1 : 'def'

  let prefixDefaults         = ''
  let s:numOptionalArguments = 0
  let directiveDetails       = ExtractInnermostDirective( result, directive )

  while ( directiveDetails.endIndex != -1 )
    if ( directiveDetails.directive ==# 'def ' )
      if ( directiveDetails.defaultValue == '' )
        let directiveDetails.defaultValue = blank
      endif

      " Capitalize first letter.
      " let variableName = substitute( directiveDetails.variable, '^.', '\u&', '\1' )
      let variableName = directiveDetails.variable

      let prefixDefaults .= "{eval {::p_override-" . variableName . "} == '' ? {" . directiveDetails.defaultValue . "::p_default-" . variableName . "} : {p_override-" . variableName . "}::n_" . directiveDetails.variable . "}"

      let result = result[ 0 : directiveDetails.startIndex ] . ( directiveDetails.modifiers == '' ? '' : directiveDetails.modifiers . '_' ) . directiveDetails.variable . result[ directiveDetails.endIndex : ]
    elseif ( directiveDetails.directive ==# 'tem ' )
      " If the match is at index 0, directiveDetails.startIndex - 1 becomes -1, which means the entire string, which isn't what we want (we want the empty string).
      let tempResult = directiveDetails.startIndex > 0 ? result[ 0 : directiveDetails.startIndex - 1 ] : ''
      let result     = tempResult . GetTemplateDefinition( directiveDetails.defaultValue ) . result[ ( directiveDetails.endIndex + 1 ) : ]
    endif

    let directiveDetails        = ExtractInnermostDirective( result, directive )
    let s:numOptionalArguments += 1
  endwhile

  " Non-default parameters first; this way, when we apply arguments, the non-default ones get filled first, leaving a shortfall to fall to the default values.
  let result = result . prefixDefaults

  return result
endfunction

let s:inputDirectiveExpression = '{::\([^_}]*_\)\=\([^}]*\)}'

function! ConsolidateDuplicateDirectives( line )
  " For each input directive, add the variable name to a dictionary. If it is already on the dictionary, remove the :: bit from it.
  let existingVariables = {}
  let result            = ''
  let startIndex        = 0
  let matchIndex        = match( a:line, s:inputDirectiveExpression, startIndex )

  while( matchIndex >= 0 )
    let result .= a:line[ startIndex : matchIndex ]
    let [ original, modifier, variable; remainder ] = matchlist( a:line, '.\{' . matchIndex . '}' . s:inputDirectiveExpression . '.*' )

    if ( !has_key( existingVariables, variable ) )
      let result .= '::'

      let existingVariables[ variable ] = ''
    endif

    let result .= modifier . variable
    let result .= '}'

    let startIndex = matchend( a:line, s:inputDirectiveExpression, startIndex )
    let matchIndex = match( a:line, s:inputDirectiveExpression, startIndex )
  endwhile

  let result .= a:line[ startIndex : ]

  return result
endfunction

" If the template name is passed in, then arguments MUST be separated by MessageFormatter_parameterSeparator.
function! PlaceTemplateForLine( lineNumber, insertMode, ... )
  let templateNameProvided = exists( "a:1" )

  if ( a:insertMode )
    " Break the undo chain so hitting undo gives the user back the word they had typed to launch this mapping.
    execute "normal! i\<c-g>u"
  endif

  let jumpCharacters = GetVar#GetVar( "MessageFormatter_jumpMarker" )
  let line           = getline( a:lineNumber )

  " Add the template name to the line and then proceed as normal.
  if ( templateNameProvided )
    let line = a:1 . GetVar#GetVar( "MessageFormatter_parameterSeparator" ) . substitute( line, '^\s*', '', '' )
  endif

  let args    = split( line, GetVar#GetVar( "MessageFormatter_parameterSeparator" ) )
  let numArgs = len( args )

  " If only one argument was found, it's possible they decided to split on single spaces with no spaces in the text.
  if ( numArgs == 1 )
    let args = split( line, '\s\+' )
    let numArgs = len( args )
  endif

  let templateName       = args[ 0 ]
  let templateDefinition = GetTemplateDefinition( templateName )

  let templateDefinition = ExpandDirectiveValues( templateDefinition, 'tem' )
  let templateDefinition = ExpandDirectiveValues( templateDefinition )
  let templateDefinition = ConsolidateDuplicateDirectives( templateDefinition )

  " By keeping the empty result, the first value can always be prepended as is--if the expression starts with a variable, it'll just be the empty string.
  let splitted  = split( templateDefinition, "{::", 1 )
  let numSplits = len( splitted )

  if ( templateDefinition == '!' . templateName . '!' )
    echo printf( "The template \"%s\" wasn't found locally or globally.", templateName )

    if ( a:insertMode )
      startinsert!
    endif

    return -1
  elseif ( numArgs < ( numSplits - s:numOptionalArguments ) )
    if ( s:numOptionalArguments > 0 )
      echo printf( "Not enough arguments for \"%s\"; need at least %d (up to %d), but got only %d.", templateName, numSplits - s:numOptionalArguments - 1, numSplits - 1, numArgs - 1 )
    else
      echo printf( "Not enough arguments for \"%s\"; need exactly %d, but got only %d.", templateName, numSplits - 1, numArgs - 1 )
    endif

    if ( a:insertMode )
      startinsert!
    endif

    return -1
  else
    let result = splitted[ 0 ]

    let argCounter = 1

    while ( argCounter < numSplits )
      let result .= '{'

      if ( argCounter < numArgs )
        let result .= args[ argCounter ] == GetVar#GetVar( "MessageFormatter_blankParameter" ) ? '' : args[ argCounter ]
      endif

      let result .= '::'
      let result .= splitted[ argCounter ]

      let argCounter += 1
    endwhile

    " Convert newlines
    let result = substitute( result, '\\n', "\n", 'g' )

    " If the expansion contains jump directives.
    if ( GetVar#GetVar( "MessageFormatter_autoAddJumpToEnd" ) == 1 && result =~# '!jump!' && result !~# '!jump!$' )
      let result .= '!jump!'
    endif

    " Convert jump directives
    let result = substitute( result, '!jump!', jumpCharacters, 'g' )

    let savedFo = &fo
    set fo=
    execute a:lineNumber
    execute "normal! cc\<c-r>=result\<esc>"
    let &fo = savedFo

    let snippetStart = line( "'[" )
    let snippetEnd   = line( "']" )

    '[,']Formatvisualrange 0

    " If the template name is not provided, jump to insert mode. (Otherwise, it was probably called from the command line.)
    if ( a:insertMode )
      call MessageFormatter#EditFirstJumpLocation( snippetStart, snippetEnd )
    endif
  endif

  return 1
endfunction

function! PlaceTemplatesForRange() range
  let lineNumber = a:lastline

  while ( lineNumber >= a:firstline )
    " Skip blank lines
    if ( getline( lineNumber ) !~ '^\s*$' )
      call PlaceTemplateForLine( lineNumber, 0 )
    endif

    let lineNumber -= 1
  endwhile
endfunction

" An add abbreviation method that replaces empty {::variable} types with {��::variable} and the very first one with a |; also replaces literal \n (backslash
" followed by an n) with newline characters.
function! AddMessageFormatterTemplate( isGlobal, args )
  let [ original, variable, expansion; remainder ] = matchlist( a:args, '^\(\S\+\)\s\+\(.*\)$' )

  let variableRoot   = a:isGlobal ? "g" : "b"
  let templateHolder = variableRoot . ':MessageFormatter_templates'

  if ( !exists( templateHolder ) )
    let {templateHolder} = {}
  endif

  let {templateHolder}[ variable ] = expansion
endfunction

function! ShowTemplates( scope, templateName )
  try
    let dictionary = {a:scope}:MessageFormatter_templates

    if ( a:templateName == '' )
      echo sort( keys (dictionary) )
    elseif ( has_key( dictionary, a:templateName ) == 1 )
      echo a:templateName . ': ' . dictionary[ a:templateName ]
    else
      let globalOrLocal = a:scope == 'g' ? 'global' : 'local'

      echo printf( "No %s template called '%s' found. List of %s templates: %s", globalOrLocal, a:templateName, globalOrLocal, string( sort( keys( dictionary ) ) ) )
    endif
  catch
    echo printf( "No %s templates defined.", a:scope == 'g' ? 'global' : 'local' )
  endtry
endfunction

function! LocalTemplateList( A, C, P )
  return exists( "b:MessageFormatter_templates" ) ? join( sort( keys( b:MessageFormatter_templates ) ), "\n" ) : ""
endfunction

function! GlobalTemplateList( A, C, P )
  return exists( "g:MessageFormatter_templates" ) ? join( sort( keys( g:MessageFormatter_templates ) ), "\n" ) : ""
endfunction

" This should be an option.
function! s:ColorDirectives()
  " syn match MessageFormatter_DirectiveDefaults '[:_]\zs\%(override\|default\)' containedin=MessageFormatter_Directive
  syntax match MessageFormatter_DirectiveModifiers '::\zs[^_}]*\ze_' containedin=MessageFormatter_Directive
  execute 'syntax match MessageFormatter_Directive ''{\%(' . GetVar#GetVar( 'MessageFormatter_jumpMarker' ) . '\)\=::.\{-}}'' containedin=ALL'
endfunction

function! SetColorDirectives( enable )
  augroup MessageFormatter
    au!
    if ( a:enable )
      au Syntax * call s:ColorDirectives()
      au ColorScheme * call s:ColorDirectives()

      call s:ColorDirectives()
    else
      syntax clear MessageFormatter_DirectiveModifiers
      syntax clear MessageFormatter_Directive
    endif
  augroup END
endfunction

function! MessageFormatter_CompleteTemplates( findstart, base )
  if ( a:findstart )
    " locate the start of the word
    let line  = getline( '.' )
    let start = col( '.' ) - 1

    while ( start > 0 && line[ start - 1 ] =~ '\S' )
      let start -= 1
    endwhile

    return start
  else
    " find months matching with "a:base"
    let templates = exists( "b:MessageFormatter_templates" ) ? b:MessageFormatter_templates : {}
    call extend( templates, g:MessageFormatter_templates )

    let res = []

    " for m in ( sort( keys( b:MessageFormatter_templates ) ) + sort( keys( g:MessageFormatter_templates ) ) )
    for m in ( sort( keys( templates ) ) )
      if ( m =~ '^' . a:base )
        let newItem = {}

        let newItem.word = m
        let newItem.menu = templates[ m ]

        call add( res, newItem )
      endif
    endfor

    return res
  endif
endfun

" Must start from the bottom and go up as the number of lines might change if the template expansion adds more lines.
function! ApplySameTemplateToMultipleLines( line1, line2, templateName )
  let lineNumber = a:line2

  while ( lineNumber >= a:line1 )
    " Skip blank lines
    if ( getline( lineNumber ) !~ '^\s*$' )
      call PlaceTemplateForLine( lineNumber, 0, a:templateName )
    endif

    let lineNumber -= 1
  endwhile
endfunction

" something to do eval  3 * 3 something else
" something to do block while something else

" SALMAN: Pass in option to have it work on word-character-only templates--would have to change the whitespace splits to \W and the \S to \w.
function! PlaceInlineTemplateForLine()
  let line         = getline( '.' )
  let originalLine = line
  let tokens       = split( line, '\s\+' )

  let i          = 0
  let definition = ''

  while ( i < len( tokens ) )
    let token      = tokens[ i ]
    let definition = GetTemplateDefinition( token, 1 )

    if ( definition != '' )
      break
    endif

    let i += 1
  endwhile

  if ( definition == '' )
    " Nothing fount; tell them.
    echo "No template name found on the line."

    return
  endif

  let cursorPosition   = getpos( '.' )[ 2 ]
  let prefixExpression = '^\(\s*\%(\S\+\s\+\)\{' . i . '}\)\(.*\)'
  let suffixExpression = '^\(.\{' . cursorPosition . '}\)\(.*\)'

  let suffix = substitute( line, suffixExpression, '\2', '' )
  let prefix = substitute( line, prefixExpression, '\1', '' )

  let line = substitute( line, suffixExpression, '\1', '' )
  let line = substitute( line, prefixExpression, '\2', '' )

  " Break the undo chain so hitting undo gives the user back the word they had typed to launch this mapping.
  execute "normal! i\<c-g>u"

  call setline( '.', line )

  let expansion = PlaceTemplateForLine( '.', 0 )

  " Success
  if ( expansion == 1 )
    let snippetStart = line( "'[" )
    let snippetEnd   = line( "']" )

    let lastLine = getline( snippetEnd )

    " Put in a jump marker right at the end of the snippet so the cursor will end up there after the expansion (if there isn't one there already as the snippet
    " might have placed one, especially if it's a block snippet).
    if ( lastLine !~ GetVar#GetVar( "MessageFormatter_jumpMarker" ) . '$' )
      let suffix = GetVar#GetVar( "MessageFormatter_jumpMarker" ) . suffix
    endif

    " GetVar#GetVar( "MessageFormatter_jumpMarker" )
    call setline( snippetEnd, lastLine . suffix )
    call setline( snippetStart, prefix . getline( snippetStart ) )

    call MessageFormatter#EditFirstJumpLocation( snippetStart, snippetEnd )
  else
    undo
    execute 'normal ' . ( cursorPosition + 1 ) . '|'
    startinsert
  endif
endfunction

com! -nargs=+ Addglobaltemplate call AddMessageFormatterTemplate( 1, <q-args> )
com! -nargs=+ Addlocaltemplate call AddMessageFormatterTemplate( 0, <q-args> )

com! -nargs=? -complete=custom,GlobalTemplateList Listglobaltemplates call ShowTemplates( 'g', <q-args> )
com! -nargs=? -complete=custom,LocalTemplateList Listlocaltemplates call ShowTemplates( 'b', <q-args> )

com! -nargs=? -range Formatvisualrange :call MessageFormatter#FormatVisualRange( <line1>, <line2>, <q-args> )

com! -nargs=+ Formatmessage echo FormatMessage( <q-args>, 0 )
com! -nargs=+ Formatmessagerecursive echo FormatMessage( <q-args>, 1 )
com! Resetformatparameters Unlet g:MessageFormatter_parameters
com! -nargs=+ Addformatparameter call AddFormatParameters( <q-args> )
com! -nargs=+ Adddictionaryformatparameter call AddDictionaryFormatParameter( <q-args> )
com! Showparameters echo GetVar#GetSafe( "g:MessageFormatter_parameters", "<No parameters have been defined.>" )
com! -nargs=+ Formatcontainedmessage echo FormatContainedMessage( <q-args> )

com! -nargs=1 Setcolordirectives call SetColorDirectives( <args> )

com! -nargs=1 -range ApplySameTemplateToMultipleLines call ApplySameTemplateToMultipleLines( <line1>, <line2>, <q-args> )


execute 'hi link MessageFormatter_DirectiveModifiers ' . GetVar#GetVar( 'MessageFormatter_highlightDirectiveModifiersLink' )
execute 'hi link MessageFormatter_Directive ' . GetVar#GetVar( 'MessageFormatter_highlightDirectivesLink' )

if ( GetVar#GetVar( 'MessageFormatter_highlightDirectives' ) == 1 )
  Setcolordirectives 1
endif


" SALMAN: Create another mechanism for a set of fixed values to be used. Let user select first few letters of one of these values instead of the whole thing; in
" case of ambiguity, first match works.

" If the template start and end were stored, expands automatically (even if the template spans multiple lines).
if ( !hasmapto( '<Plug>FormatCurrentTemplate', 'i' ) )
  imap <silent> <c-del> <Plug>FormatCurrentTemplate
endif

if ( !hasmapto( '<Plug>FormatCurrentTemplate', 'n' ) )
  nmap <silent> <c-del> <Plug>FormatCurrentTemplate
endif

if ( !hasmapto( '<Plug>PlaceTemplateInText', 'i' ) )
  imap <silent> <Leader><Leader> <Plug>PlaceTemplateInText
endif

if ( !hasmapto( '<Plug>PlaceTemplateForLine', 'i' ) )
  imap <silent> `` <Plug>PlaceTemplateForLine
endif

if ( !hasmapto( '<Plug>PlaceInlineTemplateForLine', 'i' ) )
  imap <silent> `. <Plug>PlaceInlineTemplateForLine
endif

if ( !hasmapto( '<Plug>PlaceTemplatesForRange', 'v' ) )
  vmap <silent> `` <Plug>PlaceTemplatesForRange
endif

if ( !hasmapto( '<Plug>FormatOneLine', 'n' ) )
  nmap <silent> <c-del><c-del> <Plug>FormatOneLine
endif

if ( !hasmapto( '<Plug>FormatVisualRange', 'v' ) )
  vmap <silent> <c-del> <Plug>FormatVisualRange
endif

" Mapping for operator-mode.
if ( !hasmapto( '<Plug>FormatOpModeTemplate', 'n' ) )
  nmap <silent> <c-s-del> <Plug>FormatOpModeTemplate
endif

if ( !hasmapto( '<Plug>MessageFormatter_InsertModeCompletion', 'i' ) )
  imap <silent> // <Plug>MessageFormatter_InsertModeCompletion
endif

imap <Plug>FormatCurrentTemplate <esc>:call MessageFormatter#FormatCurrentTemplate( 1 )<cr>
nmap <Plug>FormatCurrentTemplate :call MessageFormatter#FormatCurrentTemplate( 0 )<cr>
inoremap <Plug>PlaceTemplateInText <esc>:call PlaceTemplateInText()<cr>
inoremap <Plug>PlaceInlineTemplateForLine <esc>:call PlaceInlineTemplateForLine()<cr>
inoremap <Plug>PlaceTemplateForLine <esc>:call PlaceTemplateForLine( '.', 1 )<cr>
vnoremap <Plug>PlaceTemplatesForRange :call PlaceTemplatesForRange()<cr>
nmap <Plug>FormatOneLine :Formatvisualrange<cr>
vmap <Plug>FormatVisualRange :Formatvisualrange<cr>
nmap <Plug>FormatOpModeTemplate :set opfunc=MessageFormatter#FormatOpModeTemplate<cr>g@
imap <Plug>MessageFormatter_InsertModeCompletion <c-o>:set completefunc=MessageFormatter_CompleteTemplates<cr><c-x><c-u>


if ( GetVar#GetSafe( "g:MessageFormatter_createDefaultTemplates", 1 ) == 1 )
  Addglobaltemplate eval {::expression} = {eval {expression}::expressionValue}
  Addglobaltemplate evalq {eval {::expression}::expressionValue}
  Addglobaltemplate sep {eval strpart( repeat( {def =::p_separator}, {def &tw::length} ), 0, {length} )::line}
  Addglobaltemplate ca {::c_arg}
  Addglobaltemplate co {::C_arg}
  Addglobaltemplate cf {::cf_arg}
  Addglobaltemplate sc {::Cl_arg}
  Addglobaltemplate gf {eval expand( '%:p:t:r' )::thisFile}
  Addglobaltemplate td {eval strftime("%A, %B %d, %Y")::thisDate}
endif
