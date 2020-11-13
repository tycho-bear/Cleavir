(in-package #:cleavir-bir)

;;; An rtype is a "representation type", indicating the "underlying" type of an
;;; object. This is a static property distinct from its lisp type specifier.
;;; BIR knows the following rtypes:
;;; :object, meaning a general lisp object,
;;; and :multiple-values.
;;; Clients may define and use additional rtypes.
(defgeneric rtype= (rt1 rt2)
  (:method (rt1 rt2) (eql rt1 rt2)))

;;; Abstract. Something that can serve as a dynamic environment.
(defclass dynamic-environment ()
  (;; The set of iblocks that have this as their dynamic environment.
   (%scope :initarg :scope :accessor scope :initform (cleavir-set:empty-set)
           :type cleavir-set:set)))
(defun parent (dynamic-environment)
  (if (typep dynamic-environment 'function)
      nil
      (dynamic-environment (iblock dynamic-environment))))

(defgeneric rtype (datum))

(defclass datum ()
  (;; A name, for debugging/display/etc. NIL means no name.
   (%name :initarg :name :initform nil :reader name :type (or symbol null))
   (%ctype :initarg :ctype :accessor ctype)))

;;; A lexical is a datum that can be bound in an environment.
(defclass lexical (datum) ())

(defun ctyped-p (datum) (slot-boundp datum '%ctype))

(defmethod print-object ((o datum) stream)
  (print-unreadable-object (o stream :type t)
    (let ((name (name o)))
      (when name (write name :stream stream)))))

(defgeneric definitions (datum))
(defgeneric uses (datum))

;; Shortcuts so that consing may be avoided.
(defgeneric unused-p (datum)
  (:method ((datum datum)) (null (uses datum))))
(defgeneric ssa-p (datum)
  (:method ((datum datum)) (= (length (definitions datum)) 1)))

;;; A datum with only one definition (static single assignment).
(defclass ssa (datum) ())
(defgeneric definition (ssa))
(defmethod definitions ((datum ssa)) (list datum))
(defmethod ssa-p ((ssa datum)) t)

;;; A datum with only one use.
(defclass linear-datum (datum)
  ((%use :initarg :use :reader use :accessor %use
         :type instruction)))
(defmethod uses ((datum linear-datum)) (cleavir-set:make-set (use datum)))
(defmethod unused-p ((datum linear-datum))
  (not (slot-boundp datum '%use)))

;;; A datum with one definition and one use.
(defclass transfer (ssa linear-datum) ())

;;; An SSA datum with only one definition - itself.
(defclass value (ssa) ())
(defmethod definition ((datum value)) datum)

(defclass constant (value)
  ((%value :initarg :value :reader constant-value)
   (%readers :initform (cleavir-set:empty-set) :accessor readers)
   (%rtype :initarg :rtype :initform :object :reader rtype)))

;;; These variables are used for defaulting the origin and policy.
;;; If they are not bound it should still be possible to make instructions,
;;; however; default values are NIL. (TODO: Is that right for policy?)
(defvar *policy*)
(defvar *origin*)
(defun current-policy () (if (boundp '*policy*) *policy* nil))
(defun current-origin () (if (boundp '*origin*) *origin* nil))

;;; An instruction is something to be done.
;;; All instructions have sequences of inputs and outputs.
;;; Inputs are mutable but outputs may not be (for computations).
;;; Every input and output is a LINEAR-DATUM, except that READVAR has a VARIABLE
;;; input and WRITEVAR has one as an output.
(defgeneric inputs (instruction))
(defgeneric (setf inputs) (new-inputs instruction))
(defgeneric outputs (instruction))
(defgeneric (setf outputs) (new-outputs instruction))

(defclass instruction ()
  ((%predecessor :initarg :predecessor :accessor predecessor
                 :initform nil
                 ;; NIL indicates this is the first in a iblock.
                 :type (or instruction null))
   (%successor :initarg :successor :accessor successor
               ;; NIL indicates this is a terminator.
               :type (or instruction null))
   (%inputs :initarg :inputs :accessor inputs
            ;; Sequence of DATA.
            :type sequence)
   ;; The iblock this instruction belongs to.
   (%iblock :initarg :iblock :accessor iblock :type iblock)
   (%policy :initform (current-policy) :initarg :policy :reader policy)
   (%origin :initform (current-origin) :initarg :origin :reader origin)))

;;; Shortcuts to get an instruction's owner
(defmethod function ((instruction instruction))
  (function (iblock instruction)))
;;; and dynamic environment.
(defmethod dynamic-environment ((instruction instruction))
  (dynamic-environment (iblock instruction)))

;;; An instruction that outputs a single datum.
;;; In this case the instruction is identified with the datum.
(defclass computation (value transfer instruction) ())
(defmethod outputs ((instruction computation)) (list instruction))

;;; An instruction that outputs a variable number of outputs
;;; or a fixed number (that is not one) of them.
(defclass operation (instruction)
  (;; Sequence of data.
   (%outputs :initarg :outputs :accessor outputs
             :type sequence)))

;;; Data output by an OPERATION.
;;; (If a terminator, PHIs are output instead.)
(defclass output (transfer)
  ((%definition :initarg :definition
                :reader definition :accessor %definition)
   (%rtype :initarg :rtype :initform :object :reader rtype)))

;;; some useful mixins
(defclass no-input (instruction)
  ((%inputs :initform nil :type null)))
(defclass one-input (instruction)
  ((%inputs :type (cons value null))))
(defclass no-output (operation)
  ((%outputs :initform nil :type null)))

;;; An instruction that can end a iblock (abstract)
(defclass terminator (instruction)
  ((%successor :initform nil :type null)
   (%next :initarg :next :accessor next
          ;; A list of iblocks.
          :type list)))

;;; A terminator with no next iblocks (abstract)
(defclass terminator0 (terminator operation)
  ((%next :initform nil :type null)))

;;; A terminator with exactly one next iblock (abstract)
(defclass terminator1 (terminator)
  ((%next :type (cons iblock null))))

;;; An argument to a function.
(defclass argument (value transfer)
  ((%rtype :initarg :rtype :initform :object :reader rtype)))

;;; An argument to an iblock.
(defclass phi (linear-datum)
  ((%iblock :initarg :iblock :reader iblock
            :type iblock)
   (%rtype :initarg :rtype :initform :object :reader rtype)))
(defmethod definitions ((phi phi))
  (let ((ib (iblock phi))
        (definitions '()))
    (cleavir-set:doset (predecessor (predecessors ib))
      (pushnew (end predecessor) definitions))
    (cleavir-set:doset (entrance (entrances ib))
      (pushnew (end entrance) definitions))
    definitions))

;;; The ``transitive'' use of a linear datum walks through jump/phi usages.
(defun transitive-use (linear-datum)
  (loop
    (when (unused-p linear-datum)
      (return nil))
    (let ((use (use linear-datum)))
      (unless (typep use 'jump)
        (return use))
      (setq linear-datum
            (nth (position linear-datum (inputs use))
                 (outputs use))))))

;;; A mutable lexical variable.
;;; Has to be read from and written to via instructions.
(defclass variable (lexical)
  (;; Indicates the extent of a closed over variable. Filled in by
   ;; dynamic extent analysis.
   (%extent :initarg :extent :accessor extent
            :initform :unanalyzed
            :type (member :unanalyzed
                          :dynamic
                          :indefinite))
   ;; The LETI that binds this variable.
   (%binder :initarg :binder :accessor binder :type leti)
   (%definitions :accessor writers
                 :initform (cleavir-set:empty-set)
                 ;; All WRITEVAR instructions.
                 :type cleavir-set:set)
   (%uses :accessor readers
          :initform (cleavir-set:empty-set)
          ;; All READVAR instructions.
          :type cleavir-set:set)
   ;; Has this variable ever been used?
   (%use-status :initarg :use-status :initform nil :reader use-status
                :type (member nil set read))
   ;; What kind of ignore declaration is on this variable?
   (%ignore :initarg :ignore :reader ignore)
   (%rtype :initarg :rtype :initform :object :reader rtype)))

(defmethod uses ((datum variable))
  (cleavir-set:set-to-list (readers datum)))

(defmethod definitions ((datum variable))
  (cleavir-set:set-to-list (writers datum)))

(defun record-variable-set (variable)
  (with-slots (%use-status) variable
    (or %use-status (setf %use-status 'set))))

(defun record-variable-ref (variable)
  (with-slots (%use-status) variable
    (setf %use-status 'read)))

(defmethod function ((v variable))
  (function (binder v)))

(defun immutablep (variable)
  (= (cleavir-set:size (writers variable)) 1))

(defun closed-over-p (variable)
  (let ((owner (function variable)))
    (cleavir-set:doset (reader (readers variable))
      (unless (eq owner (function reader))
        (return-from closed-over-p t)))
    (cleavir-set:doset (writer (writers variable))
      (unless (eq owner (function writer))
        (return-from closed-over-p t)))))

;;; A sequence of instructions with no branching.
(defclass iblock ()
  ((%start :initarg :start :accessor start
           :type instruction)
   (%end :initarg :end :accessor end
         :type terminator)
   (%predecessors :initarg :predecessors :accessor predecessors
                  :initform (cleavir-set:empty-set)
                  ;; A set of blocks.
                  :type cleavir-set:set)
   (%inputs :initarg :inputs :accessor inputs
            :initform nil
            ;; A sequence of PHIs
            :type sequence)
   ;; A set of IBLOCKs that enter this function nonlocally
   ;; (i.e. with an UNWIND operation).
   (%entrances :initarg :entrances :accessor entrances
               :initform (cleavir-set:empty-set)
               :type cleavir-set:set)
   (%dynamic-environment :initarg :dynamic-environment
                         :accessor dynamic-environment
                         :type dynamic-environment)
   ;; The function this belongs to.
   (%function :initarg :function :accessor function :type function)
   ;; For debug/introspection
   (%name :initarg :name :reader name :initform nil)))

(defmethod print-object ((o iblock) s)
  (print-unreadable-object (o s :type t)
    (write (name o) :stream s)))

(defun iblock-started-p (iblock)
  (slot-boundp iblock '%start))

(defun successors (iblock)
  (next (end iblock)))

(defclass function (dynamic-environment value)
  ((%iblocks :initarg :iblocks :accessor iblocks
             :initform (cleavir-set:empty-set)
             :type cleavir-set:set)
   (%start :initarg :start :accessor start
           :type iblock)
   ;; Block of the return instruction.
   ;; If there isn't one, i.e. the function never returns, this is nil.
   (%end :initarg :end :accessor end :type (or null iblock))
   (%lambda-list :initarg :lambda-list :accessor lambda-list)
   ;; The set of variables bound by this function, i.e. the union of
   ;; the variables bound by all LETI instructions in it.
   (%variables :initarg :variables :accessor variables
               :initform (cleavir-set:empty-set)
               :type cleavir-set:set)
   ;; The set of catches in this function.
   (%catches :initarg :catches :accessor catches
             :initform (cleavir-set:empty-set)
             :type cleavir-set:set)
   ;; The set of lexicals closed over by this function. Currently
   ;; filled in by process-captured-variables.
   (%environment :initform (cleavir-set:empty-set) :accessor environment
                 :type cleavir-set:set)
   ;; The set of ENCLOSE instructions with this as their CODE.
   (%encloses :initform (cleavir-set:empty-set) :accessor encloses
              :type cleavir-set:set)
   ;; The set of local calls of this function.
   (%local-calls :initform (cleavir-set:empty-set) :accessor local-calls
                 :type cleavir-set:set)
   ;; For debug/introspection
   (%origin :initarg :origin :initform nil :reader origin)
   (%policy :initarg :policy :initform nil :reader policy)
   (%name :initarg :name :initform nil :reader name)
   (%docstring :initarg :docstring :initform nil :reader docstring)
   (%original-lambda-list :initarg :original-lambda-list :initform nil
                          :reader original-lambda-list)
   ;; The module containing this function.
   (%module :initarg :module :reader module :type module)))

(defmethod print-object ((o function) s)
  (print-unreadable-object (o s :type t)
    (write (name o) :stream s)))

;;; A set of functions which are compiled together (as opposed to
;;; "separate compilation") and can participate in interprocedural
;;; optimizations such as inlining. For example, lexically nested
;;; functions are always compiled together.
(defclass module ()
  ((%functions :initarg :functions :accessor functions
               :initform (cleavir-set:empty-set)
               :type cleavir-set:set)
   (%constants :accessor constants
               :initform (cleavir-set:empty-set)
               :type cleavir-set:set)
   ;; FIXME: move load time value handling more to client
   (%load-time-values :accessor load-time-values
                      :initform (cleavir-set:empty-set)
                      :type cleavir-set:set)
   ;; This table ensures that only one constant object per similar
   ;; object is created.
   (%constant-table :accessor constant-table)))

(defmethod initialize-instance :after ((module module) &key)
  ;; FIXME: In code with file compilation semantics, we are allowed to
  ;; coalesce EQUAL constants. Figure out how to allow clients to plug
  ;; into the table initialization logic here.
  (setf (constant-table module) (make-hash-table :test #'eq)))

;;; Find the constant object for CONSTANT-VALUE in MODULE, allocating
;;; a new one in the module if necessary.
(defun constant-in-module (constant-value module)
  (let ((constant-table (constant-table module)))
    (or (gethash constant-value constant-table)
        (let ((constant (make-instance 'constant :value constant-value)))
          (cleavir-set:nadjoinf (constants module) constant)
          (setf (gethash constant-value constant-table) constant)
          constant))))

;;; The set of blocks in a function that have nonlocal entrances.
(defmethod entrances ((function function))
  (let ((entrances (cleavir-set:empty-set)))
    (cleavir-set:doset (catch (catches function))
      (cleavir-set:doset (unwind (unwinds catch))
        (cleavir-set:nadjoinf entrances (destination unwind))))
    entrances))

;;; The set of blocks in a function that nonlocally exit, i.e. are terminated
;;; by UNWIND instructions.
(defmethod exits ((function function))
  (cleavir-set:filter
   'cleavir-set:set
   (lambda (ib) (typep (end ib) 'unwind))
   (iblocks function)))
