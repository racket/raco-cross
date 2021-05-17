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
(define host #f)
(define target #f)
(define native? #f)
(define skip-setup? #f)
(define skip-pkgs? #f)
(define jobs #f)
(define remove? #f)
(define compile-any? #f)

(command-line
 #:program (short-program+command-name)
 #:once-each
 [("--target") platform
               "cross-build for <platform>"
               (cond
                 [(equal? platform "any")
                  (set! compile-any? #t)]
                 [else
                  (set! target (normalize-platform
                                platform
                                #:complain-as (short-program+command-name)))])]
 [("--host") platform
             "use native <platform> for host"
             (set! host (normalize-platform
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
 [("--compile-any" "-M") "cross-build to machine-independent compilation"
                         (set! compile-any? #t)]
 [("--native") "install target platform as native to this host"
               (set! native? #t)]
 [("--workspace") dir
                  "use <dir> to hold distributions; defaults to user-specific addon space"
                  (set! workspace-dir dir)]
 [("--installers") url
                   "download distribution from <url>"
                   (set! installers-url url)]
 [("--archive") name
                "download distribution as <name> (normally ends \".tgz\")"
                (set! download-filename name)]
 [("--skip-setup") "skip the `raco setup` step of an installation"
                  (set! skip-setup? #t)]
 [("--skip-pkgs") "skip installing the \"compiler-lib\" package"
                  (set! skip-pkgs? #t)]
 [("-j" "--jobs") n
                  "use <n> parallel jobs for setup actions"
                  (set! jobs n)]
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

 ;; Infer host and target from each other
 (unless host
   (set! host (or (and target
                       (selected-host #:workspace workspace
                                      #:platform target
                                      #:vm vm))
                  (default-host-platform))))
 (unless target
   (set! target host))
 (unless (will-be-native? #:workspace workspace
                          #:platform host
                          #:host-platform #f
                          #:vm vm
                          #:compile-any? #f
                          #:install-native? #t)
   (raise-user-error (string-append
                      (short-program+command-name)
                      ": would-be host platform is installed as non-native: "
                      host)))

 (define installers (or installers-url
                        (default-installers-url version)))
 (define target-will-be-native?
   (will-be-native? #:workspace workspace
                    #:platform target
                    #:host-platform host
                    #:vm vm
                    #:compile-any? compile-any?
                    #:install-native? native?))
 (printf ">> Cross configuration\n")
 (printf " Target:    ~a~a\n" target (cond
                                       [target-will-be-native? " [native]"]
                                       [compile-any? " [machine-independent]"]
                                       [else ""]))
 (printf " Host:      ~a\n" host)
 (printf " Version:   ~a\n" version)
 (printf " VM:        ~a\n" vm)
 (printf " Workspace: ~a\n" workspace)
 (make-directory* workspace)

 (define (download #:platform platform
                   #:vm [vm vm]
                   #:compile-any? [compile-any? #f]
                   #:native? [native? #f]
                   #:zo-dir [zo-dir #f]
                   #:filename [filename #f])
   (download-distribution #:workspace workspace
                          #:platform platform
                          #:vm vm
                          #:compile-any? compile-any?
                          #:version version
                          #:installers-url installers
                          #:base-name base-name
                          #:filename filename
                          #:native? native?
                          #:host host
                          #:zo-dir zo-dir))
 (define (run args
              #:platform platform
              #:compile-any? compile-any?)
   (apply run-cross-racket
          #:workspace workspace
          #:platform platform
          #:host-platform host
          #:vm vm
          #:compile-any? compile-any?
          #:host-dir (build-path workspace (platform+vm->path host vm))
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
                         #:compile-any? compile-any?
                         #:version version)]
   [else
    ;; Get source as needed for cross compiler or
    ;; to get initial machine-independent ".zo"s
    (when (and (eq? vm 'cs)
               (not (and (equal? target host)
                         (not compile-any?)))
               (not native?))
      (download #:platform (source-platform)
                #:vm #f))

    (define (download-and-setup #:platform platform
                                #:native? native?
                                #:compile-any? [compile-any? #f]
                                #:filename [filename #f])
      (download #:platform platform
                #:native? native?
                #:filename filename
                #:compile-any? compile-any?
                #:zo-dir (and (not native?)
                              (or (eq? vm 'cs) compile-any?)
                              (build-path workspace (platform+vm->path (source-platform) #f))))
      (define done-dir (build-path workspace
                                   (platform+vm->path platform vm #:compile-any? compile-any?)
                                   "build"))
      (define done-file (build-path done-dir "setup-done"))
      (unless (file-exists? done-file)
        (unless native?
          (setup-distribution #:workspace workspace
                              #:platform platform
                              #:host-platform host
                              #:vm vm
                              #:compile-any? compile-any?
                              #:jobs jobs
                              #:skip-setup? skip-setup?))
        (run #:platform platform
             #:compile-any? compile-any?
             '("-l-" "raco" "pkg" "config" "-i" "--set" "default-scope" "installation"))
        (unless skip-pkgs?
          (run #:platform platform
               #:compile-any? compile-any?
               (append '("-l-" "raco" "pkg" "install" "--auto" "--skip-installed")
                       (if jobs (list "-j" jobs) null)
                       '("compiler-lib"))))
        (make-directory* done-dir)
        (call-with-output-file* done-file #:exists 'truncate void)))

    ;; Prepare distribution for this platform, if needed:
    (unless target-will-be-native?
      (download-and-setup #:platform host
                          #:native? #t))

    ;; Prepare distribution for target platform:
    (download-and-setup #:platform target
                        #:compile-any? compile-any?
                        #:filename download-filename
                        #:native? target-will-be-native?)

    (when command
      (run #:platform target
           #:compile-any? compile-any?
           (if (equal? command "racket")
               arg
               (list* "-l-" "raco" command arg))))]))
