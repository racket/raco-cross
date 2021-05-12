#lang racket/base
(require "platform.rkt")

(provide host-file
         as-native-file
         selected-host
         will-be-native?)

(define as-native-file "as_native")
(define host-file "use_host")

(define (selected-host #:workspace workspace
                       #:platform platform
                       #:vm vm)
  (define dir (build-path workspace (platform+vm->path platform vm)))
  (and (directory-exists? dir)
       (let ([f (build-path dir "build" host-file)])
         (and (file-exists? f)
              (call-with-input-file*
               f
               (lambda (i) (read i)))))))

(define (will-be-native? #:workspace workspace
                         #:platform platform
                         #:host-platform [host-platform (default-host-platform)]
                         #:vm vm
                         #:install-native? install-native?)
  (cond
    [(equal? platform host-platform) #t]
    [else
     (define dir (build-path workspace (platform+vm->path platform vm)))
     (cond
       [(directory-exists? dir)
        (file-exists? (build-path dir "build" as-native-file))]
       [else install-native?])]))
