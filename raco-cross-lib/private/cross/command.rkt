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
         "run.rkt"
         "build.rkt"
         "browse.rkt")

(define version (default-version))
(define workspace-dir #f) ; default is derived from version
(define installers-url #f) ; default is derived from version
(define download-filename #f)
(define vm #f)
(define base-name "racket-minimal")
(define host #f)
(define target #f)
(define native? #f)
(define skip-setup? #f)
(define skip-pkgs? #f)
(define jobs #f)
(define compile-any? #f)
(define use-source? #f)
(define rev-configure-args '())
(define quiet? #f)
(define remove? #f)
(define browse? #f)

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
                  (set! workspace-dir (path->complete-path dir))]
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
 [("--use-source") "compile a host build from source"
                   (set! use-source? #t)]
 #:multi
 [("++configure") arg "add a `configure` argument for use with --use-source"
                  (set! rev-configure-args (cons arg rev-configure-args))]
 #:once-each
 [("-q" "--quiet") "suppress startup host- and target-configuration description"
                   (set! quiet? #t)]
 #:once-any
 [("--remove") "remove installation instead of running commands"
               (set! remove? #t)]
 [("--browse") "show platforms available from installers site"
               (set! browse? #t)]
 #:args ([command #f] . arg)

 (when (and (or remove? browse?)
            command)
   (raise-user-error (string-append
                      (short-program+command-name)
                      ": "
                      (format (string-append
                               "cannot supply a command after `--~a`\n"
                               "  given command: ~a")
                              (if remove? "remove" "browse")
                              command))))

 (define installers (or installers-url
                        (default-installers-url version)))

 (when browse?
   (browse-available-platforms installers
                               version
                               vm) ; #f for `vm` => report all VMs
   (exit 0))

 (define workspace (or workspace-dir
                       (build-path (find-system-path 'addon-dir)
                                   "raco-cross"
                                   version)))

 (unless vm
   (set! vm (default-vm)))

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

 (define target-will-be-native?
   (will-be-native? #:workspace workspace
                    #:platform target
                    #:host-platform host
                    #:vm vm
                    #:compile-any? compile-any?
                    #:install-native? native?))
 (unless quiet?
   (printf ">> Cross configuration\n")
   (printf " Target:    ~a~a\n" target (cond
                                         [target-will-be-native? " [native]"]
                                         [compile-any? " [machine-independent]"]
                                         [else ""]))
   (printf " Host:      ~a\n" host)
   (printf " Version:   ~a\n" version)
   (printf " VM:        ~a\n" vm)
   (printf " Workspace: ~a\n" workspace))
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
    (define (host-built?) (directory-exists? (build-path workspace (platform+vm->path host vm))))

    ;; Get source as needed for cross compiler or
    ;; to get initial machine-independent ".zo"s
    (when (or (and (eq? vm 'cs)
                   (not (and (equal? target host)
                             (not compile-any?)))
                   (not native?))
              (and use-source?
                   (not (host-built?))))
      (download #:platform (source-platform)
                #:vm #f))

    (when (and use-source?
               (not (host-built?)))
      (build-host #:workspace workspace
                  #:platform host
                  #:vm vm
                  #:configure (reverse rev-configure-args)))

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
             '("-N" "raco" "-l-" "raco" "pkg" "config" "-i" "--set" "default-scope" "installation"))
        (run #:platform platform
             #:compile-any? compile-any?
             `("-N" "raco" "-l-" "raco" "pkg" "config"
                    "-i" "--set" "name" ,(format "~a-~a-~a"
                                                 version
                                                 platform
                                                 vm)))
        (unless skip-pkgs?
          (run #:platform platform
               #:compile-any? compile-any?
               (append '("-N" "raco" "-l-" "raco" "pkg" "install" "--auto" "--skip-installed")
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
               (list* "-N" "raco" "-l-" "raco" command arg))))]))
