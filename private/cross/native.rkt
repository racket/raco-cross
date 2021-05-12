#lang racket/base
(require "platform.rkt")

(provide as-native-file
         will-be-native?)

(define as-native-file "as_native")

(define (will-be-native? #:workspace workspace
                         #:platform platform
                         #:vm vm
                         #:install-native? install-native?)
  (cond
    [(equal? platform (host-platform)) #t]
    [else
     (define dir (build-path workspace (platform+vm->path platform vm)))
     (cond
       [(directory-exists? dir)
        (file-exists? (build-path dir "build" as-native-file))]
       [else install-native?])]))
