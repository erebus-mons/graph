;;; graph-matrix.lisp --- build and manipulate matrix graph representations

;; Copyright (C) Eric Schulte and Tom Dye 2013

;; Licensed under the Gnu Public License Version 3 or later

;;; Commentary

;; Functions for manipulating matrix graph representations.

;;; Code:
(in-package :graph-matrix)
(eval-when (:compile-toplevel :load-toplevel :execute)
  (enable-curry-compose-reader-macros))

(defconstant infinity most-positive-fixnum)

(defclass matrix ()
  ((self :initarg :self :accessor self :initform nil)))

(defclass fast-matrix (matrix) ())

(defgeneric matrix-ref (matrix row col)
  (:documentation "Return the value at ROW and COL in MATRIX."))

(defmethod matrix-ref ((matrix matrix) row col)
  (aref (self matrix) row col))

(defmethod matrix-ref ((fm fast-matrix) row col)
  (fl.function::mref (self fm) row col))

(defgeneric (setf matrix-ref) (new matrix row col)
  (:documentation "Make matrix-ref setf-able."))

(defmethod (setf matrix-ref) (new (matrix matrix) row col)
  (setf (aref (self matrix) row col) new))

(defmethod (setf matrix-ref) (new (fm fast-matrix) row col)
  (setf (fl.function::mref (self fm) row col) new))

(defgeneric matrix-n-rows (matrix)
  (:documentation "Return the number of rows in MATRIX."))

(defmethod matrix-n-rows ((matrix matrix))
  (if (self matrix)
      (array-dimension (self matrix) 0)
      0))

(defmethod matrix-n-rows ((fm fast-matrix))
  (if (self fm)
      (fl.function::nrows (self fm))
      0))

(defgeneric matrix-n-cols (matrix)
  (:documentation "Return the number of columns in MATRIX."))

(defmethod matrix-n-cols ((matrix matrix))
  (if (self matrix)
      (array-dimension (self matrix) 1)
      0))

(defmethod matrix-n-cols ((fm fast-matrix))
  (if (self fm)
      (fl.function::ncols (self fm))
      0))

(defun matrix-same-size-p (m1 m2)
  "Return t if matrix M1 has the same number of rows and columns as
matrix M2, nil otherwise."
  (and (eql (matrix-n-rows m1) (matrix-n-rows m2))
       (eql (matrix-n-cols m1) (matrix-n-cols m2))))

(defgeneric matrix-entries-different-p (m1 m2)
  (:documentation "Return nil if all the entries in matrix M1 are eql
  to the corresponding entries in matrix M2, 1 if matrix M1 is not the
  same size as matrix M2, and otherwise a list of cells that are not
  eql."))

(defmethod matrix-entries-different-p ((m1 matrix) (m2 matrix))
  (let ((result))
    (if (matrix-same-size-p m1 m2)
        (let ((m (matrix-n-rows m1))
              (n (matrix-n-cols m1)))
          (loop :for i :from 0 :below m :do
             (loop :for j :from 0 :below n :do
                (unless (eql (matrix-ref m1 i j)
                             (matrix-ref m2 i j))
                  (push (list i j) result))))
          (when result (reverse result)))
        (setf result 1))
    result))

(defun matrix-symmetric-p (matrix)
  "Return t if matrix MATRIX is symmetric, nil otherwise."
  (let* ((m (matrix-n-rows matrix))
         (n (matrix-n-cols matrix))
         (symmetric t)
        (mt (and (eql m n) (matrix-transpose matrix))))
    (loop :for i :from 0 :below m :while symmetric :when mt :do
       (loop :for j :from 0 :below n :while symmetric :do
          (unless (eql (matrix-ref matrix i j)
                       (matrix-ref mt i j))
            (setf symmetric nil))))
    (and mt symmetric)))

(defgeneric matrix-copy (matrix)
  (:documentation "Return a copy of MATRIX."))

(defmethod matrix-copy ((matrix matrix))
  (let ((result (make-instance 'matrix)))
    (when (self matrix)
      (setf (self result)
            (copy-array (self matrix))))
    result))

(defmethod matrix-copy ((fm fast-matrix))
  (let ((result (make-instance 'fast-matrix)))
    (when (self fm)
      (setf (self result) (fl.function::copy (self fm))))
    result))

(defgeneric matrix-sum (m1 m2 &key boolean)
  (:documentation "Return the result of adding matrix M1 and matrix
  M2. M1 and M2 must be the same size. If BOOLEAN is non-nil, then use
  boolean arithmetic, where 1+1=1."))

(defmethod matrix-sum ((m1 matrix) (m2 matrix) &key boolean) 
  (and (matrix-same-size-p m1 m2)
       (let ((result (matrix-copy m1))
             (m (matrix-n-rows m1))
             (n (matrix-n-cols m1)))
         (loop :for i :from 0 :below m :do
            (loop :for j :from 0 :below n :do
               (setf (matrix-ref result i j)
                     (if boolean
                         (if (> (+ (matrix-ref result i j)
                                   (matrix-ref m2 i j)) 0) 1 0)
                         (+ (matrix-ref result i j)
                            (matrix-ref m2 i j))))))
         result)))

(defmethod matrix-sum ((m1 fast-matrix) (m2 fast-matrix) &key boolean)
  (and (matrix-same-size-p m1 m2)
       (let ((result (matrix-copy m1)))
         (setf (self result) (fl.function::m+ (self result) (self m2)))
         (when boolean
           (let ((m (matrix-n-rows m1))
                 (n (matrix-n-cols m1)))
             (loop :for i :from 0 :below m :do
                (loop :for j :from 0 :below n :do
                   (if (> (matrix-ref result i j) 0)
                       (setf (matrix-ref result i j) 1))))))
         result)))

(defgeneric matrix-difference (m1 m2)
  (:documentation "Return the result of subtracting M2 from M1. M1 and
  M2 must be the same size."))

(defmethod matrix-difference ((m1 matrix) (m2 matrix))
  (and (matrix-same-size-p m1 m2)
       (let ((result (matrix-copy m1))
             (m (matrix-n-rows m1))
             (n (matrix-n-cols m1)))
         (loop :for i :from 0 :below m :do
            (loop :for j :from 0 :below n :do
               (setf (matrix-ref result i j)
                     (- (matrix-ref result i j)
                        (matrix-ref m2 i j)))))
         result)))

(defgeneric matrix-elementwise-product (m1 m2 &key boolean)
  (:documentation "Return the result of multiplying the elements of
  matrix M1 and matrix M2. M1 and M2 must be the same size."))

(defmethod matrix-elementwise-product ((m1 matrix) (m2 matrix) &key boolean)
  (and (matrix-same-size-p m1 m2)
       (let ((result (matrix-copy m1))
             (m (matrix-n-rows m1))
             (n (matrix-n-cols m1)))
         (loop :for i :from 0 :below m :do
            (loop :for j :from 0 :below n :do
               (setf (matrix-ref result i j)
                     (if boolean
                         (if (* (matrix-ref result i j)
                                (matrix-ref m2 i j)) 1 0)
                         (* (matrix-ref result i j)
                            (matrix-ref m2 i j))))))
         result)))

(defgeneric matrix-product (m1 m2)
  (:documentation "Return the result of multiplying matrix M1 and
  matrix M2. The number of columns of M1 must equal the number of rows
  of M2."))

(defmethod matrix-product ((m1 matrix) (m2 matrix))
  (and (eql (matrix-n-cols m1) (matrix-n-rows m2))
       (loop
          :with m = (matrix-n-rows m1)
          :with n = (matrix-n-cols m1)
          :with l = (matrix-n-cols m2)
          :with c = (make-zeros-matrix (make-instance 'matrix) m l)
          :for i :below m :do
          (loop :for k :below l :do
             (setf (matrix-ref c i k)
                   (loop :for j :below n
                      :sum (* (matrix-ref m1 i j)
                              (matrix-ref m2 j k)))))
          :finally (return c)))  )

(defmethod matrix-product ((m1 fast-matrix) (m2 fast-matrix))
  (and (eql (matrix-n-cols m1) (matrix-n-rows m2))
       (let ((result (make-instance 'fast-matrix)))
         (setf (self result) (fl.function::m* (self m1) (self m2)))
         result)))

(defgeneric matrix-transpose (matrix)
  (:documentation "Return a new matrix that interchanges the rows and
  columns of MATRIX."))

(defmethod matrix-transpose ((matrix matrix))
  (let ((m (matrix-n-rows matrix))
        (n (matrix-n-cols matrix))
        (result (make-instance 'matrix)))
    (setf result (make-zeros-matrix result n m))
    (loop :for i :from 0 :below m :do
       (loop :for j :from 0 :below n :do
          (setf (matrix-ref result j i)
                (matrix-ref matrix i j))))
    result))

(defmethod matrix-transpose ((fm fast-matrix))
  (let ((result (make-instance 'fast-matrix)))
    (setf (self result) (fl.function::transpose (self fm)))
    result))

(defgeneric make-zeros-matrix (matrix rows cols)
  (:documentation "Return matrix MATRIX with ROWS rows and COLS
  columns of zeros."))

(defmethod make-zeros-matrix ((matrix matrix) rows cols)
  (setf (self matrix) (make-array (list rows cols)
                                  :element-type 'fixnum
                                  :initial-element 0))
  matrix)

(defmethod make-zeros-matrix ((fm fast-matrix) rows cols)
  (setf (self fm) (fl.function::zeros rows cols 'fixnum))
  fm)

(defgeneric make-universal-matrix (matrix rows cols)
  (:documentation "Return a universal matrix with ROWS rows and COLS columns."))

(defmethod make-universal-matrix ((matrix matrix) rows cols)
  (setf (self matrix) (make-array (list rows cols)
                                  :element-type 'fixnum
                                  :initial-element 1))
  matrix)

(defmethod make-universal-matrix ((fm fast-matrix) rows cols)
  (setf (self fm) (fl.function::ones rows cols 'fixnum))
  fm)

(defgeneric make-infinity-matrix (matrix rows cols)
  (:documentation "Return a matrix of ROWS rows and COLS cols with
  each entry set to infinity"))

(defmethod make-infinity-matrix ((matrix matrix) rows cols)
  (progn
    (setf (self matrix) (make-array (list rows cols)
                                    :element-type 'fixnum
                                    :initial-element infinity))
    matrix))

; Can't get a femlisp solution to work
(defmethod make-infinity-matrix ((fm fast-matrix) rows cols)
  (progn
    (setf (self fm) (fl.function::zeros rows cols 'fixnum))
    (loop :for i :from 0 :below rows :do
       (loop :for j :from 0 :below cols :do
          (setf (matrix-ref fm i j) infinity)))
    fm))

(defgeneric make-identity-matrix (matrix order)
  (:documentation "Return an identity matrix of order ORDER."))

(defmethod make-identity-matrix ((matrix matrix) order)
  (setf matrix (make-zeros-matrix matrix order order))
  (loop :for i :from 0 :below order :do
     (setf (matrix-ref matrix i i) 1))
  matrix)

(defmethod make-identity-matrix ((fm fast-matrix) order)
  (setf (self fm) (fl.function::eye order order 'fixnum))
  fm)

(defgeneric to-adjacency-matrix (graph matrix)
  (:documentation "Return the adjacency matrix of GRAPH."))

(defmethod to-adjacency-matrix ((graph graph) (matrix matrix))
  (let ((node-index-hash (make-hash-table))
        (counter -1))
    (mapc (lambda (node) (setf (gethash node node-index-hash) (incf counter)))
          (nodes graph))
    (setf matrix (make-zeros-matrix matrix (+ counter 1) (+ counter 1)))
    (mapc (lambda-bind ((a b))
                       (setf (matrix-ref matrix
                                         (gethash a node-index-hash)
                                         (gethash b node-index-hash))
                             1)
                       (setf (matrix-ref matrix
                                         (gethash b node-index-hash)
                                         (gethash a node-index-hash))
                             1))
          (edges graph))
    matrix))

(defmethod to-adjacency-matrix ((graph digraph) (matrix matrix))
  (let ((node-index-hash (make-hash-table))
        (counter -1))
    (mapc (lambda (node) (setf (gethash node node-index-hash) (incf counter)))
          (nodes graph))
    (setf matrix (make-zeros-matrix matrix (+ counter 1) (+ counter 1)))
    (mapc (lambda-bind ((a b))
                       (setf (matrix-ref matrix
                                         (gethash a node-index-hash)
                                         (gethash b node-index-hash))
                             1))
          (edges graph))
    matrix))

(defgeneric to-reachability-matrix (graph matrix &key limit)
  (:documentation "Return the reachability matrix of the graph GRAPH.
  With the optional argument LIMIT set to an integer in the range 2 to
  two less than the number of nodes in GRAPH, produces a limited
  reachability matrix with paths of length LIMIT or less."))

(defmethod to-reachability-matrix ((graph graph) (matrix matrix) &key limit)
  (assert (or (not limit) (and (integerp limit) (> limit 1)
                               (< limit (- (length (nodes graph)) 1))))
          (limit)
          "~S must be an integer between 2 and ~S"
          limit (- (length (nodes graph)) 2))
  (let* ((result (make-identity-matrix (matrix-copy matrix)
                                       (length (nodes graph))))
         (max-power (or limit (- (length (nodes graph)) 1)))
         (adjacency (to-adjacency-matrix graph (matrix-copy matrix)))
         (adjacency-powers (matrix-copy adjacency)))
    (setf result (matrix-sum adjacency result :boolean t))
    (loop :for i :from 2 :to max-power :do
       (setf adjacency-powers (matrix-product adjacency-powers adjacency))
       (setf result (matrix-sum adjacency-powers result :boolean t)))
    result))

(defgeneric reachablep (graph rd from to)
  (:documentation "Given a graph GRAPH and a reachability matrix
  RD, returns t if TO is reachable from FROM, nil
  otherwise."))

(defmethod reachablep ((graph graph) (rd matrix) from to)
  (let ((node-index-hash (make-hash-table))
        (counter -1))
    (mapc (lambda (node) (setf (gethash node node-index-hash) (incf counter)))
          (nodes graph))
    (eql 1 (matrix-ref rd
                       (gethash from node-index-hash)
                       (gethash to node-index-hash)))))

(defgeneric reachable-from (graph rd from)
  (:documentation "Given a reachability matrix RD, return a list of
  the nodes in graph GRAPH reachable from node FROM."))

(defmethod reachable-from ((graph graph) (rd matrix) from)
  (let ((node-index-hash (make-hash-table))
        (counter -1)
        (result))
    (mapc (lambda (node) (setf (gethash node node-index-hash) (incf counter)))
          (nodes graph))
    (maphash #'(lambda (k v)
                 (unless
                     (equal 0
                            (matrix-ref rd
                                        (gethash from node-index-hash)
                                        v))
                   (push k result)))
             node-index-hash)
    (reverse result)))

(defgeneric to-strong-component-matrix (rd)
  (:documentation "Given a reachability matrix of a digraph, RD,
  return a matrix in which the strong component of GRAPH containing
  node_i is given by the entries of 1 in the ith row (or column)."))

(defmethod to-strong-component-matrix ((rd matrix))
  (matrix-elementwise-product rd (matrix-transpose rd)))

(defgeneric strong-component-of (node graph strong-components)
  (:documentation "Return a list of nodes from graph GRAPH in the
  strong component that contains node NODE, as given by the strong
  component matrix STRONG-COMPONENTS."))

(defmethod strong-component-of (node (graph graph) (strong-components matrix))
  (let ((node-index-hash (make-hash-table))
        (counter -1)
        (result))
    (mapc (lambda (node) (setf (gethash node node-index-hash) (incf counter)))
          (nodes graph))
    (maphash #'(lambda (k v)
                 (unless (equal 0 (matrix-ref
                                   strong-components
                                   (gethash node node-index-hash) v))
                   (push k result)))
             node-index-hash)
    (reverse result)))

(defgeneric to-distance-matrix (graph nd)
  (:documentation "Return the distance matrix ND of graph GRAPH."))

(defmethod to-distance-matrix ((graph graph) (nd matrix))
  (let* ((a (to-adjacency-matrix graph (matrix-copy nd)))
         (a-power (to-adjacency-matrix graph (matrix-copy nd)))
         (m (matrix-n-rows a))
         (finished))
    (setf nd (make-infinity-matrix nd m m))
    (loop :for i :from 0 :below m :do
       (setf (matrix-ref nd i i) 0))
    (loop :for i :from 0 :below m :do
       (loop :for j :from 0 :below m :do
          (when (eql (matrix-ref a i j) 1)
            (setf (matrix-ref nd i j) 1))))
    (loop :for i :from 2 :to m :unless finished :do
       (setf a-power (matrix-product a a-power))
       (setf finished t)
       (loop :for j :from 0 :below m :do
          (loop :for k :from 0 :below m :do
             (when (and (eql (matrix-ref nd j k) infinity)
                        (> (matrix-ref a-power j k) 0))
               (setf (matrix-ref nd j k) i)
               (setf finished nil)))))
    nd))

(defgeneric distance-from-to (graph nd from to)
  (:documentation "Returns the number of edges in graph GRAPH from
  node FROM to node TO, given the distance matrix ND."))

(defmethod distance-from-to ((graph graph) (nd matrix) from to)
  (let ((node-index-hash (make-hash-table))
        (counter -1))
    (mapc (lambda (node) (setf (gethash node node-index-hash) (incf counter)))
          (nodes graph))
    (matrix-ref nd
                (gethash from node-index-hash)
                (gethash to node-index-hash))))

;; Peirce's relational properties

(defun reflexivep (graph matrix)
  :documentation "Returns t if GRAPH is reflexive, nil otherwise."
  (let ((a (to-adjacency-matrix graph matrix))
        (result))
    (loop :for j :from 0 :below (matrix-n-rows a) :unless result :do
       (setf result (not (eql 1 (matrix-ref a j j)))))
    (not result)))

(defun irreflexivep (graph matrix)
  :documentation "Returns t if GRAPH is irreflexive, nil otherwise."
  (let ((a (to-adjacency-matrix graph matrix))
        (result))
    (loop :for j :from 0 :below (matrix-n-rows a) :unless result :do
       (setf result (not (eql 0 (matrix-ref a j j)))))
    (not result)))

(defun symmetricp (graph matrix)
  :documentation "Returns t if GRAPH is symmetric, nil otherwise."
  (let* ((a (to-adjacency-matrix graph matrix))
         (at (matrix-transpose a)))
    (if (matrix-entries-different-p a at) nil t)))

(defun asymmetricp (graph matrix)
  :documentation "Returns t if GRAPH is asymmetric, nil otherwise."
  (let* ((a (to-adjacency-matrix graph matrix))
        (at (matrix-transpose a))
        (result))
    (loop :for j :from 0 :below (matrix-n-rows a) :unless result :do
       (loop :for k :from 0 :below (matrix-n-rows a) :unless result :do
          (setf result (and (not (eq j k))
                        (eq (matrix-ref a j k) 1)
                        (eq (matrix-ref at j k) 1)))))
    (not result)))

(defun transitivep (graph matrix)
  :documentation "Returns t if GRAPH is transitive, nil otherwise."
  (let* ((a (to-adjacency-matrix graph matrix))
         (a2 (matrix-product a a))
         (two-path)
         (no-match))
    (loop :for j :from 0 :below (matrix-n-rows a) :do
       (loop :for k :from 0 :below (matrix-n-rows a) :do
          (and (not two-path) (eq (matrix-ref a2 j k) 1)
               (setf two-path j))
          (and (not no-match) (eq (matrix-ref a2 j k) 1)
               (eq (matrix-ref a j k) 0)
               (setf no-match j))))
    (and two-path (not no-match))))

(defun intransitivep (graph matrix)
  :documentation "Returns t if GRAPH is intransitive, nil otherwise."
  (let* ((a (to-adjacency-matrix graph matrix))
         (a2 (matrix-product a a))
         (two-path)
         (match))
    (loop :for j :from 0 :below (matrix-n-rows a) :do
       (loop :for k :from 0 :below (matrix-n-rows a) :do
          (and (not two-path) (eq (matrix-ref a2 j k) 1)
               (setf two-path j))
          (and (not match) (not (eq j k))
               (eq (matrix-ref a2 j k) 1)
               (eq (matrix-ref a j k) 1)
               (setf match j))))
    (and two-path (not match))))

(defun completep (graph matrix)
  :documentation "Returns t if GRAPH is complete, nil otherwise."
  (let* ((a (to-adjacency-matrix graph matrix)) 
         (at (matrix-transpose a))
         (result))
    (loop :for j :from 0 :below (matrix-n-rows a) :unless result :do
       (loop :for k :from 0 :below (matrix-n-rows a)
          :unless (or result (eq j k)) :do
          (setf result (and (eq (graph-matrix::matrix-ref a j k) 0)
                            (eq (graph-matrix::matrix-ref at j k) 0)))))
    (not result)))

(defun relational-structure (graph matrix)
  :documentation "Returns a string with the name of a relational
  structure whose axiom system GRAPH satisfies, or nil if no
  relational structure axiom system is satisfied."
    (let ((rnobar (reflexivep graph matrix))
        (rbar (irreflexivep graph matrix))
        (snobar (symmetricp graph matrix))
        (sbar (asymmetricp graph matrix))
        (tnobar (transitivep graph matrix))
        (tbar (intransitivep graph matrix))
        (cnobar (completep graph matrix)))
    (or
     (when (and rbar
                (not (or snobar sbar tnobar tbar cnobar))) "digraph")
     (when (and rbar snobar
                (not (or tnobar tbar cnobar))) "graph")
     (when (and rbar sbar
                (not (or tnobar tbar cnobar))) "oriented graph")
     (when (and rnobar snobar
                (not tnobar)) "similarity relation")
     (when (and rnobar snobar tnobar
                (not cnobar)) "equivalence relation")
     (when (and rbar sbar tnobar
                (not cnobar)) "partial order")
     (when (and rbar sbar tnobar cnobar) "complete order")
     (when (and rbar sbar cnobar
                (not (or tnobar tbar))) "tournament")
     (when (and rbar snobar tnobar
                (not cnobar)) "parity relation")
     (when (and rbar sbar tbar
                (not cnobar)) "antiequivalence relation")
     (when (and rnobar sbar tbar) "antiparity relation"))))
