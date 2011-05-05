if ( exists( "g:MessageFormatter_loaded" || &compatible || version < 703 ) )
  finish
endif

let g:MessageFormatter_loaded = 1


if ( !exists( "g:MessageFormatter_blankParameter" ) )
  let g:MessageFormatter_blankParameter = '`'
endif

if ( !exists( "g:MessageFormatter_parameterSeparator" ) )
  let g:MessageFormatter_parameterSeparator = '\s\{2,}'
endif

if ( !exists( "g:MessageFormatter_jumpMarker" ) )
  let g:MessageFormatter_jumpMarker = '«»'
endif

if ( !exists( "g:MessageFormatter_formatCurrentLineAsFallback" ) )
  let g:MessageFormatter_formatCurrentLineAsFallback = 1
endif

if ( !exists( "g:MessageFormatter_autoAddJumpToEnd" ) )
  let g:MessageFormatter_autoAddJumpToEnd = 1
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

" Where the cursor should go.
" |
" |
" a|b
" ||
" \%(^\|[^|]\)\zs|\ze\%([^|]\|$\)
function! PlaceTemplateInText()
  " Break the undo chain so hitting undo gives the user back the word they had typed to launch this mapping.
  execute "normal! i\<c-g>u"

  let saveZ = @z

  normal "zdiW

  let templateName = @z

  let @z = saveZ

  let result = GetTemplateDefinition( templateName )

  let result = ExpandDefaultValues( result )

  " Used to do this right in the AddMessageFormatterTemplate but it's easier to do it here on demand in case they have already provided the arguments on the
  " command-line.
  " Make the first one the cursor location.
  let result = substitute( result, '{::', '{|::', '' )
  " Make the rest placeholders for jumping.
  let result = substitute( result, '{::', '{!jump!::', 'g' )
  " Convert newlines
  let result = substitute( result, '\\n', "\n", 'g' )

  " SALMAN: If there are ny !jump! directives, make sure to add one at the very end to jump to.
  " Convert jump directives
  let result = substitute( result, '!jump!', GetVar#GetVar( "MessageFormatter_jumpMarker" ), 'g' )

  undojoin

  let savedFo = &fo
  set fo=
  execute 'normal! a' . result . "\<esc>"
  let &fo = savedFo

  " Store for automatic expansion later.
  let b:MessageFormatter_snippetStart = line( "'[" )
  let b:MessageFormatter_snippetEnd   = line( "']" )

  normal '[0

  " Either the beginning of the line or a non-pipe character followed by a pipe followed by a non-pipe charcter or the end of the line. Forces the system to find
  " a single pipe character (avoiding the || boolean construct).
  let searchPosition = search( '\%(^\|[^|]\)\zs|\ze\%([^|]\|$\)', 'cW', line( "']" ) )

  if ( searchPosition > 0 )
    normal "_x
    startinsert
  else
    normal ']
    startinsert!
  endif
endfunction

function! GetTemplateDefinition( templateName )
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
    let result = '!' . a:templateName . '!'
  endif

  return result
endfunction

let s:openBrace  = '_OPEN_BRACE_'
let s:closeBrace = '_CLOSE_BRACE_'

" echo ExtractInnermostDefault( "public static final {::type} {::C_var} = {def {var}::n_value}{eval '{type}' == 'String' ? {qp_value} : {p_value}::parsedValue};" )
function! ExtractInnermostDefault( line )
  let defaultString  = "def "
  let defaultLength  = strlen( defaultString )
  let lineLength     = strlen( a:line )
  let defaultDetails = {}

  let defaultDetails.startIndex   = -1
  let defaultDetails.endIndex     = -1
  let defaultDetails.defaultValue = ''
  let defaultDetails.modifiers    = ''
  let defaultDetails.variable     = ''

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
      if ( currentPointer < lineLength - defaultLength )
        let testCharacters = a:line[ currentPointer : currentPointer + defaultLength - 1 ]

        if ( testCharacters == defaultString )
          let defaultDetails.startIndex = currentPointer - 1
          let currentPointer           += defaultLength
          let parsingDefault            = 1
          let value                     = ''
          let newDirective              = 1
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
          let parsingDefault          = 0
          let defaultDetails.endIndex = currentPointer - 1

          " SALMAN: Capture the value here
          let [ expression, defaultDetails.defaultValue, defaultDetails.modifiers, defaultDetails.variable; remainder ] = matchlist( value, '\(.*\)::\%(\([^_]*\)_\)\=\(.*\)' )

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

  return defaultDetails
endfunction

" Recursive def should work now; for example:
" echo ExpandDefaultValues( "public static final {::type} {::C_var} = {def {var}::n_value}{eval '{type}' == 'String' ? {qp_value} : {p_value}::parsedValue};" )
function! ExpandDefaultValues( line )
  let result = a:line

  let blank = GetVar#GetVar( "MessageFormatter_blankParameter" )

  let prefixDefaults         = ''
  let s:numOptionalArguments = 0
  let defaultDetails         = ExtractInnermostDefault( result )

  while ( defaultDetails.startIndex != -1 )
    if ( defaultDetails.defaultValue == '' )
      let defaultDetails.defaultValue = blank
    endif

    let prefixDefaults .= "{eval {::p_temp" . s:numOptionalArguments . "} == '' ? {" . defaultDetails.defaultValue . "::p_def" . s:numOptionalArguments . "} : {p_temp" . s:numOptionalArguments . "}::n_" . defaultDetails.variable . "}"

    let result = result[ 0 : defaultDetails.startIndex ] . ( defaultDetails.modifiers == '' ? '' : defaultDetails.modifiers . '_' ) . defaultDetails.variable . result[ defaultDetails.endIndex : ]

    let defaultDetails          = ExtractInnermostDefault( result )
    let s:numOptionalArguments += 1
  endwhile

  " Non-default parameters first; this way, when we apply arguments, the non-default ones get filled first, leaving a shortfall to fall to the default values.
  let result = result . prefixDefaults

  return result
endfunction

function! PlaceTemplateForLine( lineNumber )
  " Break the undo chain so hitting undo gives the user back the word they had typed to launch this mapping.
  execute "normal! i\<c-g>u"

  let jumpCharacters = GetVar#GetVar( "MessageFormatter_jumpMarker" )
  let line           = getline( a:lineNumber )

  let args    = split( line, GetVar#GetVar( "MessageFormatter_parameterSeparator" ) )
  let numArgs = len( args )

  " If only one argument was found, it's possible they decided to split on single spaces with no spaces in the text.
  if ( numArgs == 1 )
    let args = split( line, '\s\+' )
    let numArgs = len( args )
  endif

  let templateName       = args[ 0 ]
  let templateDefinition = GetTemplateDefinition( templateName )

  let templateDefinition = ExpandDefaultValues( templateDefinition )

  " By keeping the empty result, the first value can always be prepended as is--if the expression starts with a variable, it'll just be the empty string.
  let splitted  = split( templateDefinition, "{::", 1 )
  let numSplits = len( splitted )

  if ( templateDefinition == '!' . templateName . '!' )
    echo printf( "The template \"%s\" wasn't found locally or globally.", templateName )

    startinsert!
  elseif ( numArgs < ( numSplits - s:numOptionalArguments ) )
    if ( s:numOptionalArguments > 0 )
      echo printf( "Not enough arguments; need at least %d (up to %d), including the command itself, but got only %d.", numSplits - s:numOptionalArguments, numSplits, numArgs )
    else
      echo printf( "Not enough arguments; need exactly %d, including the command itself, but got only %d.", numSplits, numArgs )
    endif

    startinsert!
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
    execute "normal! cc\<c-r>=result\<esc>"
    let &fo = savedFo

    let snippetStart = line( "'[" )
    let snippetEnd   = line( "']" )

    '[,']Formatvisualrange 0

    execute snippetStart
    normal! 0

    " If a jump marker is found, put the cursor there; otherwise, move it to the end of the expansion.
    let searchPosition = search( jumpCharacters, 'cW', snippetEnd )

    if ( searchPosition > 0 )
      execute 'normal "_' . strlen( jumpCharacters ) . 'x'
      startinsert
    else
      normal ']
      startinsert!
    endif
  endif
endfunction

" An add abbreviation method that replaces empty {::variable} types with {«»::variable} and the very first one with a |; also replaces literal \n (backslash
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

com! -nargs=+ Addglobaltemplate call AddMessageFormatterTemplate( 1, <q-args> )
com! -nargs=+ Addlocaltemplate call AddMessageFormatterTemplate( 0, <q-args> )

com! -nargs=? Listglobaltemplates call ShowTemplates( 'g', <q-args> )
com! -nargs=? Listlocaltemplates call ShowTemplates( 'b', <q-args> )

com! -nargs=? -range Formatvisualrange :call MessageFormatter#FormatVisualRange( <line1>, <line2>, <q-args> )

com! -nargs=+ Formatmessage echo FormatMessage( <q-args>, 0 )
com! -nargs=+ Formatmessagerecursive echo FormatMessage( <q-args>, 1 )
com! Resetformatparameters Unlet g:MessageFormatter_parameters
com! -nargs=+ Addformatparameter call AddFormatParameters( <q-args> )
com! -nargs=+ Adddictionaryformatparameter call AddDictionaryFormatParameter( <q-args> )
com! Showparameters echo GetVar#GetSafe( "g:MessageFormatter_parameters", "<No parameters have been defined.>" )
com! -nargs=+ Formatcontainedmessage echo FormatContainedMessage( <q-args> )

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

imap <Plug>FormatCurrentTemplate <esc>:call MessageFormatter#FormatCurrentTemplate( 1 )<cr>
nmap <Plug>FormatCurrentTemplate :call MessageFormatter#FormatCurrentTemplate( 0 )<cr>
inoremap <Plug>PlaceTemplateInText <esc>:call PlaceTemplateInText()<cr>
inoremap <Plug>PlaceTemplateForLine <esc>:call PlaceTemplateForLine( '.' )<cr>
nmap <Plug>FormatOneLine :Formatvisualrange<cr>
vmap <Plug>FormatVisualRange :Formatvisualrange<cr>
nmap <Plug>FormatOpModeTemplate :set opfunc=MessageFormatter#FormatOpModeTemplate<cr>g@

if ( GetVar#GetSafe( "g:MessageFormatter_createDefaultTemplates", 1 ) == 1 )
  Addglobaltemplate get public {::type} {eval '{type}' ==? 'boolean' ? 'is' : 'get'::get}{::cf_property}()\n{\nreturn m_{c_property};\n}
  Addglobaltemplate set public void set{::cf_property}( {::type} val )\n{\nm_{c_property} = val;\n}
  Addglobaltemplate getset public {::type} {eval '{type}' ==? 'boolean' ? 'is' : 'get'::get}{::cf_property}()\n{\nreturn m_{c_property};\n}\n\npublic void set{cf_property}( {type} val )\n{\nm_{c_property} = val;\n}
  Addglobaltemplate getseta public {::type} {eval '{type}' =~? 'boolean' ? 'is' : 'get'::get}{::cf_property}( int index )\n{\nreturn m_{c_property}[ index ];\n}\n\npublic void set{cf_property}( {type} val, int index )\n{\nm_{c_property}[ index ] = val;\n}
  Addglobaltemplate var {::type} {::c_var} = new {eval {p_type} =~# '^List' ? 'Array{type}' : {p_type} =~# '^Map' ? 'Hash{type}' : {p_type}::instanceType}();
  Addglobaltemplate const public static final {::type} {::C_var} = {def {var}::n_value}{eval '{type}' == 'String' ? {qp_value} : {p_value}::parsedValue};
  Addglobaltemplate down {::subclass} {::variable} = ({subclass}) {::parentVariable};
  Addglobaltemplate safetern ( {::var} == null ? "" : {var} )
  Addglobaltemplate do do\n{\n!jump!\n} while ( !jump! );
  Addglobaltemplate eval {::expression} = {eval {expression}::expressionValue}
  Addglobaltemplate evalq {eval {::expression}::expressionValue}
endif
