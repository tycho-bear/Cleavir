(cl:in-package #:asdf-user)

(defsystem :cleavir-lexical
  :depends-on (:acclimation :trucler-reference)
  :serial t
  :components
  ((:file "packages")))
