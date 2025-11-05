; extends

; styled.div`...` - member expression
((call_expression
  function: (member_expression
    object: (identifier) @_styled
    property: (property_identifier))
  arguments: (template_string
    (string_fragment) @injection.content))
  (#eq? @_styled "styled")
  (#set! injection.language "css"))

; styled(Component)`...` - call expression
((call_expression
  function: (call_expression
    function: (identifier) @_styled)
  arguments: (template_string
    (string_fragment) @injection.content))
  (#eq? @_styled "styled")
  (#set! injection.language "css"))

; css`...` - css helper
((call_expression
  function: (identifier) @_css
  arguments: (template_string
    (string_fragment) @injection.content))
  (#eq? @_css "css")
  (#set! injection.language "css"))

; createGlobalStyle`...`
((call_expression
  function: (identifier) @_createGlobalStyle
  arguments: (template_string
    (string_fragment) @injection.content))
  (#eq? @_createGlobalStyle "createGlobalStyle")
  (#set! injection.language "css"))

; keyframes`...`
((call_expression
  function: (identifier) @_keyframes
  arguments: (template_string
    (string_fragment) @injection.content))
  (#eq? @_keyframes "keyframes")
  (#set! injection.language "css"))
