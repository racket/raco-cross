#lang racket/base
(require racket/system
         "platform.rkt"
         "default.rkt"
         "xpatch.rkt"
         "run.rkt")

(provide setup-distribution)

;; Compiles ".zo" files using a distribution for the host machine
;; and a source distribution.

(define (setup-distribution #:workspace workspace-dir
                            #:platform platform ; arch+OS
                            #:vm [vm (default-vm)]
                            #:host-dir [host-dir (build-path workspace-dir
                                                             (platform+vm->path
                                                              (host-platform)
                                                              vm))]
                            #:source-dir [source-dir (build-path workspace-dir
                                                                 (platform+vm->path
                                                                  (source-platform)
                                                                  #f))]
                            #:force? [force? #f])
  (define platform+vm (platform+vm->path platform vm))
  (define target-dir (build-path workspace-dir platform+vm))

  (define machine (platform->machine platform))

  (when (eq? vm 'cs)
    (generate-xpatch #:src-dir source-dir
                     #:host-racket-dir host-dir
                     #:machine machine))

  (printf ">> Setting up for ~a\n" platform+vm)

  (unless (run-cross-racket* #:target-dir target-dir
                             #:machine machine
                             #:host-dir host-dir
                             #:source-dir source-dir
                             #:vm vm
                             '("-l-"
                               "raco"
                               "setup"
                               "-D"
                               "-x"
                               "--no-pkg-deps"))
    (unless force?
      (error 'setup-distribution "setup failed"))))
