#lang info

(define collection "raco")

(define raco-commands (("cross"
                        raco/private/cross/command
                        "drive cross-compilation commands"
                        #f)))

(define deps '("base"))
