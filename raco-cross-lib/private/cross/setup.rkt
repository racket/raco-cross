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
                            #:host-platform [host-platform (default-host-platform)]
                            #:vm [vm (default-vm)]
                            #:compile-any? [compile-any? #f]
                            #:host-dir [host-dir (build-path workspace-dir
                                                             (platform+vm->path
                                                              host-platform
                                                              vm))]
                            #:source-dir [source-dir (build-path workspace-dir
                                                                 (platform+vm->path
                                                                  (source-platform)
                                                                  #f))]
                            #:force? [force? #f]
                            #:skip-setup? [skip-setup? #f]
                            #:jobs [jobs #f])
  (define platform+vm (platform+vm->path platform vm #:compile-any? compile-any?))
  (define target-dir (build-path workspace-dir platform+vm))

  (define machine (and (not compile-any?) (platform->machine platform)))

  (when (and (eq? vm 'cs)
             machine)
    (generate-xpatch #:src-dir source-dir
                     #:host-racket-dir host-dir
                     #:machine machine
                     #:host-machine (platform->machine host-platform)))

  (unless skip-setup?
    (printf ">> Setting up for ~a\n" platform+vm)

    (unless (run-cross-racket* #:target-dir target-dir
                               #:machine machine
                               #:host-dir host-dir
                               #:source-dir source-dir
                               #:vm vm
                               (append
                                '("-N"
                                  "raco"
                                  "-l-"
                                  "raco"
                                  "setup"
                                  "--no-user"
                                  "-D"
                                  "-x"
                                  "--no-pkg-deps")
                                (if jobs (list "-j" jobs) null)))
      (unless force?
        (error 'setup-distribution "setup failed")))))
