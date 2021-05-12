#lang info

(define collection "raco")

(define raco-commands '(("cross"
                         raco/private/cross/command
                         "drive commands for cross compilation"
                         #f)))

(define deps '("base"))
