(in-package #:cleavir-bir-transformations)

;;; Attempt to optimize a variable.
(defun optimize-variable (variable)
  (let ((readers (cleavir-bir:readers variable))
        (writers (cleavir-bir:writers variable)))
    ;; Unreferenced variable can be deleted.
    (when (cleavir-set:empty-set-p readers)
      (cleavir-set:doset (writer writers)
        (cleavir-bir:delete-instruction writer)))))

(defun function-optimize-variables (function)
  (cleavir-set:doset (variable (cleavir-bir:variables function))
    (optimize-variable variable)))

(defun module-optimize-variables (module)
  (cleavir-bir:map-functions #'function-optimize-variables module))
