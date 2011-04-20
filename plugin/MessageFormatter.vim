function! FormatMessage( message, recursive )
  if ( !exists( "g:MessageFormatter_parameters" ) )
    return a:message
  endif

  return MessageFormatter#FormatMessage( a:message, g:MessageFormatter_parameters, a:recursive )
endfunction
com! -nargs=+ Formatmessage echo FormatMessage( <q-args>, 0 )
com! -nargs=+ Formatmessagerecursive echo FormatMessage( <q-args>, 1 )

com! Resetformatparameters Unlet g:MessageFormatter_parameters

function! AddFormatParameters( ... )
  call Allocate( "g:MessageFormatter_parameters", [] )

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
com! -nargs=+ Addformatparameter call AddFormatParameters( <q-args> )

function! AddDictionaryFormatParameter( arg )
  let [ dummy, key, value; rest ] = matchlist( a:arg, '^\(\S\+\)\s\+\(.*\)$' )

  call Allocate( "g:MessageFormatter_parameters", {} )

  " List; can't add.
  if ( type( g:MessageFormatter_parameters ) == 3 )
    echoerr "The parameters are contained a List, not a Dictionary. To just add the parameter as is, use Addformatparameter instead."

    echo "The parameter list: " . string( g:MessageFormatter_parameters )

    return
  endif

  let g:MessageFormatter_parameters[ key ] = value
endfunction
com! -nargs=+ Adddictionaryformatparameter call AddDictionaryFormatParameter( <q-args> )

com! Showparameters echo GetSafe( "g:MessageFormatter_parameters", "<No parameters have been defined.>" )

function! IncrementCurrentPointer()
  let s:MessageFormatter_currentPointer += 1
endfunction

function! ExtractVariableName()
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
      let value .= '{' . ExtractVariableName() . '}'
    elseif ( char == ':' )
      " Value/variable name separator (::).
      if ( s:MessageFormatter_text[ s:MessageFormatter_currentPointer ] == ':' )
        let valueFinished = 1

        call IncrementCurrentPointer()
      else
        let value .= char
      endif
    elseif ( char == '}' )
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
    if ( value =~# 'ask\%( \|$\)' )
      let defaultValue = substitute( value, 'ask\%( \(.*\)\)\=', '\1', '' )
      let s:MessageFormatter_parameters[ variableName ] = "eval input( 'Enter value for " . variableName . ": ', '" . defaultValue . "' )"
    else
      let s:MessageFormatter_parameters[ variableName ] = value
    endif
  endif

  return ( modifiers == '' ? '' : modifiers . '_' ) . variableName
endfunction

function! FormatContainedMessage( text, ... )
  let s:MessageFormatter_text           = a:text
  let s:MessageFormatter_parameters     = exists( "a:1" ) && type( a:1 ) == 4 ? a:1 : {}
  let s:MessageFormatter_currentPointer = 0

  let messageToFormat = ExtractVariableName()

  return MessageFormatter#FormatMessage( messageToFormat, s:MessageFormatter_parameters, 1 )
endfunction
com! -nargs=+ Formatcontainedmessage echo FormatContainedMessage( <q-args> )

" let s:MessageFormatter_text = 'I am {Salman::full name}'
" let s:MessageFormatter_text = 'My last name is {last name} and my full name is {Salman {Halim::last name}::full name}.'
" let s:MessageFormatter_text ="/**\<c-j> * Comment for {c_0}.\<c-j> */\<c-j>public static final {int::type} {minutes in hour::Ce_0} = {eval '{type}' ==# 'String' ? '\"{0}\"' : '«»'::1};"
" Decho FormatContainedMessage( "/**\<c-j> * Comment for {c_0}.\<c-j> */\<c-j>public static final {int::type} {hours in minute::Ce_0} = {eval '{type}' ==# 'String' ? '\"{0}\"' : '«»'::1};" )
" Decho FormatContainedMessage( "/**\<c-j> * Comment for {c_0}.\<c-j> */\<c-j>public static final {String::type} {some other constants to be used::Ce_0} = {eval '{type}' ==# 'String' ? '\"{0}\"' : '«»'::1};" )

" Decho FormatContainedMessage( "{String::n_type}{minutes in hours::n_0}{::n_value}/**\<c-j> * Comment for {c_0}.\<c-j> */\<c-j>public static final {type} {Ce_0} = {eval '{value}' == '' ? '{1}' : '{value}'::retval}{eval '{type}' ==# 'String' ? '\"{0}\"' : '«»'::n_1};" )

" Decho FormatContainedMessage('{ask John::n_first name}{ask Smith::n_last name}My first name is {first name} and my last name is {last name}, making me {{last name}, {first name}::u_full name}')
