(in-package #:cleavir-abstract-interpreter)

(defclass reachability->data (scalar-channel)
  ((%input :type reachability) (%output :type data)))

(defmethod flow-instruction ((channel reachability->data) (instruction bir:instruction)
                             &rest infos)
  ;; If an instruction is unreachable, all its outputs are the infimum.
  (values-list (make-list (length (bir:outputs instruction))
                          :initial-element (if (null (first infos))
                                               (infimum (output channel))
                                               (supremum (output channel))))))
(defmethod flow-instruction ((channel reachability->data) (inst bir:one-output)
                             &rest infos)
  (if (null (first infos))
      (infimum (output channel))
      (supremum (output channel))))
(defmethod flow-instruction ((channel reachability->data) (inst bir:no-output)
                             &rest infos)
  (declare (ignore infos))
  (values))
