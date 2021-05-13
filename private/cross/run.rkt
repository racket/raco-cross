#lang racket/base
(require racket/system
         "platform.rkt"
         "default.rkt"
         "host-racket.rkt"
         "native.rkt")

(provide run-cross-racket
         run-cross-racket*)

(define (run-cross-racket #:workspace workspace-dir
                          #:platform platform ; arch+OS
                          #:host-platform [host-platform (default-host-platform)]
                          #:vm [vm (default-vm)]
                          #:host-dir [host-dir (build-path workspace-dir
                                                           (platform+vm->path
                                                            host-platform
                                                            vm))]
                          #:source-dir [source-dir (build-path workspace-dir
                                                               (platform+vm->path
                                                                (source-platform)
                                                                #f))]
                          #:on-fail [on-fail (lambda ()
                                               (error "command failed"))]
                          . args)
  (define platform+vm (platform+vm->path platform vm))
  (define target-dir (build-path workspace-dir platform+vm))

  (define machine (platform->machine platform))

  (unless (run-cross-racket* #:target-dir target-dir
                             #:machine machine
                             #:host-dir host-dir
                             #:source-dir source-dir
                             #:vm vm
                             args)
    (on-fail)))

(define (run-cross-racket* #:target-dir target-dir
                           #:machine machine
                           #:host-dir host-dir
                           #:source-dir source-dir
                           #:vm vm
                           args)
  (cond
    [(file-exists? (build-path target-dir "build" as-native-file))
     (define racket (find-host-racket target-dir))
     (apply system* racket args)]
    [else
     (define racket (find-host-racket host-dir))
     (define zo-dir (path->complete-path (build-path target-dir "build" "zo")))

     (apply system* racket
            (append
             (if (eq? vm 'cs)
                 (list "--cross-compiler"
                       machine (build-path source-dir "lib")
                       "-MCR" (bytes-append (path->bytes zo-dir)
                                            (if (eq? 'windows (system-type))
                                                #";"
                                                #":")))
                 (list "-C"))
             (list
              "-G" (build-path target-dir "etc")
              "-X" (build-path target-dir "collects"))
             args))]))
