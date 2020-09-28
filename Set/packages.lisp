(cl:in-package #:common-lisp-user)

(defpackage #:cleavir-set
  (:use #:cl)
  (:shadow #:set #:nunion #:every)
  (:export #:set #:empty-set #:make-set #:arb #:set<= #:set=
           #:nadjoin #:nadjoinf #:nremove #:nremovef
           #:nunion #:nunionf #:difference
           #:presentp #:size #:empty-set-p #:copy-set
           #:doset #:mapset #:set-to-list #:filter #:every))
