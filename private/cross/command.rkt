#lang racket/base
(require racket/cmdline
         raco/command-name
         racket/file
         "default.rkt"
         "platform.rkt"
         "download.rkt"
         "setup.rkt"
         "run.rkt")

(define version (default-version))
(define workspace-dir #f) ; default is derived from version
(define installers-url #f) ; default is derived from version
(define vm (default-vm))
(define base-name "racket-minimal")
(define target (host-platform))

(command-line
 #:program (short-program+command-name)
 #:once-each
 [("--target") platform
               "cross-build for <platform>"
               (set! target (normalize-platform
                             platform
                             #:complain-as (short-program+command-name)))]
 [("--work-dir") dir
                 "use <dir> to hold distributions; defaults to user-specific addon space"
                 (set! workspace-dir dir)]
 [("--version") vers
                "use Racket distributions with version number <vers>"
                (set! version vers)]
 [("--vm") variant
           "use Racket distributions for <variant>, either `cs` or `bc`"
           (set! vm (case variant
                      [("cs") 'cs]
                      [("bc") 'bc]
                      [else (raise-user-error
                             (short-program+command-name)
                             "unrecognized variant: "
                             variant)]))]
 [("--installers") url
                   "download installers from <url>"
                   (set! installers-url url)]
 #:args ([command #f] . arg)
 (define workspace (or workspace-dir
                       (build-path (find-system-path 'addon-dir)
                                   "raco-cross"
                                   version)))
 (define installers (or installers-url
                        (default-installers-url version)))
 (printf ">> Cross configuration\n")
 (printf " Target:    ~a\n" target)
 (printf " Host:      ~a\n" (host-platform))
 (printf " Version:   ~a\n" version)
 (printf " VM:        ~a\n" vm)
 (printf " Workspace: ~a\n" workspace)
 (make-directory* workspace)

 (define (download #:platform platform
                   #:vm [vm vm]
                   #:zo-dir [zo-dir #f])
   (download-distribution #:workspace workspace
                          #:platform platform
                          #:vm vm
                          #:version version
                          #:installers-url installers
                          #:base-name base-name
                          #:zo-dir zo-dir))
 
 (when (and (eq? vm 'cs)
            (not (equal? target (host-platform))))
   ;; Get source, needed for cross compiler
   (download #:platform (source-platform)
             #:vm #f))
 ;; Get distribution for this platform:
 (download #:platform (host-platform))
 ;; Get and set up target platform:
 (unless (equal? target (host-platform))
   (download #:platform target
             #:zo-dir (and (eq? vm 'cs)
                           (build-path workspace (platform+vm->path (source-platform) #f))))
   (define done-dir (build-path workspace
                                (platform+vm->path target vm)
                                "build"))
   (define done-file (build-path done-dir "setup-done"))
   (unless (file-exists? done-file)
     (setup-distribution #:workspace workspace
                         #:platform target
                         #:vm vm)
     (make-directory* done-dir)
     (call-with-output-file* done-file #:exists 'truncate void)))

 (when command
   (apply run-cross-racket
          #:workspace workspace
          #:platform target
          #:vm vm
          #:host-dir (build-path workspace (platform+vm->path (host-platform) vm))
          #:on-fail (lambda ()
                      (raise-user-error (short-program+command-name)
                                        "command failed"))
          (if (equal? command "racket")
              arg
              (list* "-l-" "raco" command arg)))))
