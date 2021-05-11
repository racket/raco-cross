#lang racket/base

(provide default-vm
         default-version)

(define (default-vm)
  (case (system-type 'vm)
    [(chez-scheme) "cs"]
    [else "bc"]))

(define (default-version)
  (car (regexp-match #rx"^[0-9]+.[0-9]+" (version))))
