#lang racket/base
(require racket/system)

(provide find-host-racket
         run-host-racket)

(define (find-host-racket host-dir)
  (define (try p)
    (and (file-exists? p)
         p))
  (or (try (build-path host-dir "bin" "racket"))
      (try (build-path host-dir "Racket.exe"))
      (error 'run
             "host racket executable not found\n  installation: ~a"
             host-dir)))

(define (run-host-racket host-dir . args)
  (apply system*
         (find-host-racket host-dir)
         args
         #:set-pwd? #t))
