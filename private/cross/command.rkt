#lang racket/base
(require raco/command-name)

(command-line
 #:program (short-program+command-name)
 #:args (command . arg)
 (cons command arg))

