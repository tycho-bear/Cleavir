(cl:in-package #:common-lisp-user)

(defpackage #:cleavir-bir
  (:use #:cl)
  (:shadow #:function #:catch #:variable #:load-time-value #:case
           #:disassemble #:ignore)
  (:export #:module #:functions #:constants #:constant-in-module
           #:load-time-values #:load-time-value-in-module)
  (:export #:function #:iblocks #:start #:end #:inputs #:variables #:catches
           #:environment
           #:local-calls #:lambda-list #:name #:docstring #:original-lambda-list)
  (:export #:dynamic-environment #:scope #:parent)
  (:export #:iblock #:predecessors #:entrances #:iblock-started-p)
  (:export #:rtype #:rtype=)
  (:export #:datum #:ssa #:value #:linear-datum #:transfer #:argument #:phi
           #:delete-phi #:output #:name #:ctype #:derived-type
           #:definition #:definitions #:use #:transitive-use #:unused-p)
  (:export #:variable #:extent #:writers #:readers #:binder
           #:use-status #:ignore
           #:record-variable-ref #:record-variable-set
           #:immutablep #:closed-over-p)
  (:export #:constant #:load-time-value
           #:constant-value #:form #:read-only-p)
  (:export #:instruction #:inputs #:outputs #:input
           #:terminator #:terminator0 #:terminator1
           #:successor #:predecessor #:next
           #:origin #:policy)
  (:export #:*origin* #:*policy* #:*top-ctype* #:*top-function-ctype*)
  (:export #:multiple-to-fixed #:fixed-to-multiple
           #:accessvar #:writevar #:readvar #:cast
           #:constant-reference #:make-constant-reference
           #:load-time-value-reference #:make-load-time-value-reference
           #:returni #:unreachable #:jump #:unwindp
           #:eq-test #:typeq-test #:test-ctype
           #:ifi #:conditional-test
           #:case #:comparees
           #:catch #:unwinds #:unwind #:destination
           #:values-save #:values-collect
           #:alloca #:writetemp #:readtemp
           #:abstract-call #:callee #:call #:local-call
           #:abstract-local-call #:mv-call #:mv-local-call
           #:attributes #:transforms
           #:leti #:dynamic-leti #:enclose #:code
           #:thei #:asserted-type #:type-check-function #:delete-thei)
  (:export #:primop #:vprimop #:nvprimop #:tprimop #:info)
  (:export #:do-functions #:map-functions)
  (:export #:compute-iblock-flow-order)
  (:export #:do-iblocks #:map-iblocks)
  (:export #:map-iblock-instructions #:map-iblock-instructions-backwards
           #:do-iblock-instructions)
  (:export #:map-local-instructions
           #:insert-instruction-before #:insert-instruction-after
           #:delete-instruction
           #:delete-ftm-mtf-pair #:replace-uses #:replace-terminator
           #:split-block-after #:delete-iblock #:maybe-delete-iblock
           #:clean-up-iblock #:merge-successor-if-possible #:delete-iblock-if-empty)
  (:export #:map-lambda-list)
  (:export #:verify)
  (:export #:disassemble)
  (:export #:unused-variable #:type-conflict))
