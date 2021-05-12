#lang racket/base

(provide default-vm
         default-version
         default-installers-url)

(define (default-vm)
  (case (system-type 'vm)
    [(chez-scheme) 'cs]
    [else 'bc]))

(define (default-version)
  (car (regexp-match #rx"^[0-9]+.[0-9]+(?:.[1-9][0-0]*)?" (version))))

(define (default-installers-url vers)
  (format "https://mirror.racket-lang.org/installers/~a/" vers))
