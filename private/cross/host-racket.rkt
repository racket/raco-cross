#lang racket/base
(require racket/system)

(provide find-host-racket
         run-host-racket)

(define (find-host-racket host-dir)
  (build-path host-dir "bin" "racket"))

(define (run-host-racket host-dir . args)
  (apply system*
         (find-host-racket host-dir)
         args
         #:set-pwd? #t))
