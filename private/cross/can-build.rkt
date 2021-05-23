#lang racket/base

(provide can-build-platform?)

(define (can-build-platform?)
  (not (eq? (system-type) 'windows)))

