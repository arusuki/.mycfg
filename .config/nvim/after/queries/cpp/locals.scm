; extends
;
; The default C++ locals query covers method declarations, but not method
; definitions inside a class. Both C++ and CUDA use field_identifier for
; the declarator in that case.
(function_definition
  declarator: (function_declarator
    declarator: (field_identifier) @local.definition.method))
