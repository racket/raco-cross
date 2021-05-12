#lang info

(define collection "raco")

(define raco-commands '(("cross"
                         raco/private/cross/command
                         "drive commands for cross compilation"
                         #f)))

(define scribblings '(("private/cross/raco-cross.scrbl"
                       ()
                       (tool))))

(define deps '("base"))

(define build-deps '("racket-doc"
                     "scribble-lib"))
