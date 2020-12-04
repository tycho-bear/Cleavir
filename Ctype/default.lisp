(in-package #:cleavir-ctype)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; This is a default implementation of the ctype protocol, for clients that
;;; don't want to bother implementing it themselves.
;;; In this implementation, ctypes are CL type specifiers, though stripped of
;;; environment dependency. CL:SUBTYPEP etc. are used.

;;; Internal: Check whether the given default ctype is a values ctype.
(defun values-ctype-p (ctype)
  (and (consp ctype) (eql (car ctype) 'cl:values)))

;;; Given a possibly non-values ctype, return a values ctype for it.
(defmethod coerce-to-values (ctype sys)
  (declare (ignore sys))
  (if (values-ctype-p ctype)
      ctype
      `(cl:values ,ctype &optional &rest t)))

(defmethod subtypep (ct1 ct2 sys)
  (declare (ignore sys))
  (cl:subtypep ct1 ct2))

(defmethod upgraded-array-element-type (ct sys)
  (declare (ignore sys))
  (cl:upgraded-array-element-type ct))

(defmethod upgraded-complex-part-type (ct sys)
  (declare (ignore sys))
  (cl:upgraded-complex-part-type ct))

(defmethod top (sys) (declare (ignore sys)) 't)
(defmethod bottom (sys) (declare (ignore sys)) 'nil)

(defmethod top-p (ctype sys)
  (declare (ignore sys))
  (or (eql ctype 't)
      ;; Kinda KLUDGEy way to avoid (find-class 't),
      ;; which needs an environment.
      (and (cl:typep ctype 'class)
           (eql (class-name ctype) 't))))

(defmethod bottom-p (ctype sys)
  (declare (ignore sys))
  ;; We assume that NIL is not a class.
  (eql ctype 'nil))

;;; Internal
(defun intersection-ctype-p (ctype)
  (and (consp ctype) (eq (car ctype) 'and)))
(defun intersection-ctypes (ctype) (rest ctype))
(defun union-ctype-p (ctype)
  (and (consp ctype) (eq (car ctype) 'or)))
(defun union-ctypes (ctype) (rest ctype))
(defun function-ctype-p (ctype)
  (and (consp ctype) (eq (car ctype) 'cl:function)))
(defun function-return (ctype) (third ctype))

(defun values-conjoin (vct1 vct2 sys)
  (loop with required1 = (values-required vct1 sys)
        with optional1 = (values-optional vct1 sys)
        with rest1 = (values-rest vct1 sys)
        with required2 = (values-required vct2 sys)
        with optional2 = (values-optional vct2 sys)
        with rest2 = (values-rest vct2 sys)
        with required with optional with rest
        with donep = nil
        do (if (null required1)
               (if (null optional1)
                   (if (null required2)
                       (if (null optional2)
                           ;; rest v rest
                           (setf rest (conjoin/2 rest1 rest2 sys)
                                 donep t)
                           ;; rest v opt
                           (push (conjoin/2 rest1 (pop optional2) sys)
                                 optional))
                       ;; rest v req
                       (push (conjoin/2 rest1 (pop required2) sys)
                             required))
                   (if (null required2)
                       (if (null optional2)
                           ;; optional v rest
                           (push (conjoin/2 (pop optional1) rest2 sys)
                                 optional)
                           ;; optional v optional
                           (push (conjoin/2 (pop optional1) (pop optional2) sys)
                                 optional))
                       ;; optional v req
                       (push (conjoin/2 (pop optional1) (pop required2) sys)
                             required)))
               (if (null required2)
                   (if (null optional2)
                       ;; required v rest
                       (push (conjoin/2 (pop required1) rest2 sys)
                             required)
                       ;; required v optional
                       (push (conjoin/2 (pop required1) (pop optional2) sys)
                             required))
                   ;; required v required
                   (push (conjoin/2 (pop required1) (pop required2) sys)
                         required)))
        when donep
          return (values (nreverse required) (nreverse optional) rest sys)))

(defmethod conjoin/2 (ct1 ct2 sys)
  (cond
    ((and (values-ctype-p ct1) (values-ctype-p ct2))
     (values-conjoin ct1 ct2 sys))
    ;; Pick off some very basic cases.
    ((or (bottom-p ct1 sys) (bottom-p ct2 sys)) 'nil)
    ((top-p ct1 sys) ct2)
    ((top-p ct2 sys) ct1)
    ((cl:subtypep ct1 ct2) ct1)
    ((cl:subtypep ct2 ct1) ct2)
    (t (let ((ty `(and ,ct1 ,ct2)))
         ;; Checking for bottom-ness is a very basic
         ;; canonicalization we can perform with the
         ;; limited tools CL gives us.
         (if (cl:subtypep ty nil)
             nil
             ty)))))

(defun values-disjoin (vct1 vct2 sys)
  (loop with required1 = (values-required vct1 sys)
        with optional1 = (values-optional vct1 sys)
        with rest1 = (values-rest vct1 sys)
        with required2 = (values-required vct2 sys)
        with optional2 = (values-optional vct2 sys)
        with rest2 = (values-rest vct2 sys)
        with required with optional with rest
        with donep = nil
        do (if (null required1)
               (if (null optional1)
                   (if (null required2)
                       (if (null optional2)
                           ;; rest v rest
                           (setf rest (disjoin/2 rest1 rest2 sys)
                                 donep t)
                           ;; rest v opt
                           (push (disjoin/2 rest1 (pop optional2) sys)
                                 optional))
                       ;; rest v req
                       (push (disjoin/2 rest1 (pop required2) sys)
                             optional))
                   (if (null required2)
                       (if (null optional2)
                           ;; optional v rest
                           (push (disjoin/2 (pop optional1) rest2 sys)
                                 optional)
                           ;; optional v optional
                           (push (disjoin/2 (pop optional1) (pop optional2) sys)
                                 optional))
                       ;; optional v req
                       (push (disjoin/2 (pop optional1) (pop required2) sys)
                             optional)))
               (if (null required2)
                   (if (null optional2)
                       ;; required v rest
                       (push (disjoin/2 (pop required1) rest2 sys)
                             optional)
                       ;; required v optional
                       (push (disjoin/2 (pop required1) (pop optional2) sys)
                             optional))
                   ;; required v required
                   (push (disjoin/2 (pop required1) (pop required2) sys)
                         required)))
        when donep
          return (values (nreverse required) (nreverse optional) rest sys)))

(defmethod disjoin/2 (ct1 ct2 sys)
  (cond
    ((and (values-ctype-p ct1) (values-ctype-p ct2))
     (values-disjoin ct1 ct2 sys))
    ((or (top-p ct1 sys) (top-p ct2 sys)) 't)
    ((bottom-p ct1 sys) ct2)
    ((bottom-p ct2 sys) ct1)
    ((cl:subtypep ct1 ct2) ct2)
    ((cl:subtypep ct2 ct1) ct1)
    (t `(or ,ct1 ,ct2))))

(defmethod negate (ct sys)
  (cond ((top-p ct sys) 'nil)
        ((bottom-p ct sys) 't)
        (t `(not ,ct))))

(defmethod subtract (ct1 ct2 sys)
  (cond ((bottom-p ct1 sys) 'nil)
        ((bottom-p ct2 sys) ct1)
        ((top-p ct2 sys) 'nil)
        (t `(and ,ct1 (not ,ct2)))))

(defun function-returns (fctype) (third fctype))

(defun general-function-returns (fctype system)
  (cond ((function-ctype-p fctype)
         (function-returns fctype))
        ((intersection-ctype-p fctype)
         (cl:apply #'conjoin system (intersection-ctypes fctype)))
        ((union-ctype-p fctype)
         (cl:apply #'disjoin system (union-ctypes fctype)))
        ;; give up
        (t `(cl:values &rest t))))

(defmethod apply (fctype actype system)
  (declare (ignore actype))
  (general-function-returns fctype system))

(defmethod funcall (system fctype &rest atypes)
  (declare (ignore atypes))
  (general-function-returns fctype system))

(defmethod cons (car cdr sys)
  (declare (ignore sys))
  (cond ((eql car 'nil) 'nil)
        ((eql cdr 'nil) 'nil)
        (t `(cl:cons ,car ,cdr))))

(defmethod array (element dimensions simplicity sys)
  (declare (ignore sys))
  `(,simplicity ,element ,dimensions))

(defmethod complex (part sys)
  (declare (ignore sys))
  `(cl:complex ,part))

(defmethod range (type low high sys)
  (declare (ignore sys))
  `(,type ,low ,high))

(defmethod member (sys &rest elems)
  (declare (ignore sys))
  `(cl:member ,@elems))

(defmethod null-type (sys)
  (declare (ignore sys))
  'cl:null)

(defmethod satisfies (fname sys)
  (declare (ignore sys))
  `(cl:satisfies ,fname))

(defmethod function (req opt rest keyp keys aokp returns sys)
  (declare (ignore sys))
  `(cl:function (,@req &optional ,@opt &rest ,rest
                       ,@(when keyp `(&key ,keys))
                       ,@(when aokp '(&allow-other-keys)))
                ,returns))

(defmethod values (req opt rest sys)
  (declare (ignore sys))
  `(cl:values ,@req &optional ,@opt &rest ,rest))

;;; These readers work on the premise that these type specifiers
;;; are normalized by the other methods, so they always have
;;; certain lambda list keywords.

(defun ll-required (lambda-list)
  (ldiff lambda-list (cl:member '&optional lambda-list)))

(defun ll-optional (lambda-list)
  (ldiff (cl:rest (cl:member '&optional lambda-list))
         (cl:member '&rest lambda-list)))

(defun ll-rest (lambda-list)
  (second (cl:member '&rest lambda-list)))

(defun ll-keysp (lambda-list)
  (cl:member '&key lambda-list))

(defun ll-keys (lambda-list)
  (let ((res (cl:member '&key lambda-list)))
    (if res
        (ldiff res (cl:member '&allow-other-keys res))
        nil)))

(defun ll-aokp (lambda-list)
  (cl:member '&allow-other-keys lambda-list))

(defmethod values-required (ctype system)
  (declare (ignore system))
  (ll-required (cl:rest ctype)))

(defmethod values-optional (ctype system)
  (declare (ignore system))
  (ll-optional (cl:rest ctype)))

(defmethod values-rest (ctype system)
  (declare (ignore system))
  (ll-rest (cl:rest ctype)))
