#lang info

(define collection "raco")

(define scribblings '(("private/cross/raco-cross.scrbl"
                       ()
                       (tool))))

(define deps '("base"))

(define build-deps '("raco-cross-lib"
                     "racket-doc"
                     "scribble-lib"))
