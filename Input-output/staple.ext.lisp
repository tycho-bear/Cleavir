(in-package #:cleavir-documentation-generation)

(defmethod staple:page-type ((sys (eql (asdf:find-system :cleavir-io))))
  'cleavir-page)
