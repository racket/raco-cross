#lang racket/base
(require racket/cmdline
         raco/command-name
         racket/file
         "default.rkt"
         "platform.rkt"
         "native.rkt"
         "remove.rkt"
         "download.rkt"
         "setup.rkt"
         "run.rkt")

(define version (default-version))
(define workspace-dir #f) ; default is derived from version
(define installers-url #f) ; default is derived from version
(define download-filename #f)
(define vm (default-vm))
(define base-name "racket-minimal")
(define target (host-platform))
(define native? #f)
(define remove? #f)

(command-line
 #:program (short-program+command-name)
 #:once-each
 [("--target") platform
               "cross-build for <platform>"
               (set! target (normalize-platform
                             platform
                             #:complain-as (short-program+command-name)))]
 [("--version") vers
                "use Racket distributions with version number <vers>"
                (set! version vers)]
 [("--vm") variant
           "use Racket distributions for <variant>, either `cs` or `bc`"
           (set! vm (case variant
                      [("cs") 'cs]
                      [("bc") 'bc]
                      [else (raise-user-error
                             (string-append (short-program+command-name)
                                            ": unrecognized variant: "
                                            variant))]))]
 [("--native") "install target platform as native to this host"
               (set! native? #t)]
 [("--work-dir") dir
                 "use <dir> to hold distributions; defaults to user-specific addon space"
                 (set! workspace-dir dir)]
 [("--installers") url
                   "download distribution from <url>"
                   (set! installers-url url)]
 [("--archive") name
                "download distribution as <name> (normally ends \".tgz\")"
                (set! download-filename name)]
 [("--remove") "remove installation instead of running commands"
               (set! remove? #t)]
 #:args ([command #f] . arg)

 (when (and remove? command)
   (raise-user-error (string-append
                      (short-program+command-name)
                      ": "
                      (format "~a\n  given command: ~a"
                              "cannot supply a command after `--remove`"
                              command))))

 (define workspace (or workspace-dir
                       (build-path (find-system-path 'addon-dir)
                                   "raco-cross"
                                   version)))
 (define installers (or installers-url
                        (default-installers-url version)))
 (define target-will-be-native?
   (will-be-native? #:workspace workspace
                    #:platform target
                    #:vm vm
                    #:install-native? native?))
 (printf ">> Cross configuration\n")
 (printf " Target:    ~a~a\n" target (if target-will-be-native?
                                         " [native]"
                                         ""))
 (printf " Host:      ~a\n" (host-platform))
 (printf " Version:   ~a\n" version)
 (printf " VM:        ~a\n" vm)
 (printf " Workspace: ~a\n" workspace)
 (make-directory* workspace)

 (define (download #:platform platform
                   #:vm [vm vm]
                   #:native? [native? #f]
                   #:zo-dir [zo-dir #f]
                   #:filename [filename #f])
   (download-distribution #:workspace workspace
                          #:platform platform
                          #:vm vm
                          #:version version
                          #:installers-url installers
                          #:base-name base-name
                          #:filename filename
                          #:native? native?
                          #:zo-dir zo-dir))
 (define (run args #:platform platform)
   (apply run-cross-racket
          #:workspace workspace
          #:platform platform
          #:vm vm
          #:host-dir (build-path workspace (platform+vm->path (host-platform) vm))
          #:on-fail (lambda ()
                      (raise-user-error (string-append
                                         (short-program+command-name)
                                         ": command failed")))
          args))

 (cond
   [remove?
    (remove-distribution #:workspace workspace
                         #:platform target
                         #:vm vm
                         #:version version)]
   [else
    ;; Get source as needed for cross compiler
    (when (and (eq? vm 'cs)
               (not (equal? target (host-platform)))
               (not native?))
      (download #:platform (source-platform)
                #:vm #f))

    (define (download-and-setup #:platform platform
                                #:native? native?
                                #:filename [filename #f])
      (download #:platform platform
                #:native? native?
                #:filename filename
                #:zo-dir (and (not native?)
                              (eq? vm 'cs)
                              (build-path workspace (platform+vm->path (source-platform) #f))))
      (define done-dir (build-path workspace
                                   (platform+vm->path platform vm)
                                   "build"))
      (define done-file (build-path done-dir "setup-done"))
      (unless (file-exists? done-file)
        (unless native?
          (setup-distribution #:workspace workspace
                              #:platform platform
                              #:vm vm))
        (run #:platform platform
             '("-l-" "raco" "pkg" "config" "-i" "--set" "default-scope" "installation"))
        (make-directory* done-dir)
        (call-with-output-file* done-file #:exists 'truncate void)))

    ;; Prepare distribution for this platform, if needed:
    (unless native?
      (download-and-setup #:platform (host-platform)
                          #:native? #t))

    ;; Prepare distirbution for target platform:
    (download-and-setup #:platform target
                        #:filename download-filename
                        #:native? (or native?
                                      (equal? target (host-platform))))

    (when command
      (run #:platform target
           (if (equal? command "racket")
               arg
               (list* "-l-" "raco" command arg))))]))
