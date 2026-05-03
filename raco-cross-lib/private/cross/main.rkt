#lang racket/base
(require raco/command-name
         racket/file
         "default.rkt"
         "workspace.rkt"
         "platform.rkt"
         "native.rkt"
         "remove.rkt"
         "download.rkt"
         "setup.rkt"
         "run.rkt"
         "build.rkt"
         "browse.rkt")

(provide raco-cross)

(define (raco-cross #:version [version #f]
                    #:workspace-dir [workspace-dir #f] ; default is derived from version
                    #:installers-url [installers-url #f] ; default is derived from version
                    #:archive [download-filename #f]
                    #:vm [vm #f]
                    #:base-name [base-name "racket-minimal"]
                    #:host [host #f]
                    #:target [target #f]
                    #:native? [native? #f]
                    #:skip-setup? [skip-setup? #f]
                    #:skip-pkgs? [skip-pkgs? #f]
                    #:jobs [jobs #f]
                    #:compile-any? [compile-any? #f]
                    #:use-source? [use-source? #f]
                    #:configure-args [configure-args '()]
                    #:addon-dir [addon-dir #f]
                    #:quiet? [quiet? #f]
                    #:remove? [remove? #f]
                    #:browse? [browse? #f]
                    #:command [command #f]
                    . args)
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

  (define ws-version
    (and workspace-dir
         (workspace-version workspace-dir)))

  (unless version
    (set! version (or ws-version
                      (default-version))))
  (when (and ws-version
             (not (equal? version ws-version)))
    (raise-user-error (string-append
                       (short-program+command-name)
                       (format
                        (string-append
                         ": version mismatch for workspace\n"
                         "  workspace: ~a\n"
                         "  workspace version: ~a\n"
                         "  requested version: ~a")
                        workspace-dir
                        ws-version
                        version))))

  (define installers (or installers-url
                         (and workspace-dir
                              (workspace-installers-url workspace-dir))
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
  (record-workspace-version workspace version)
  (when (and workspace-dir installers-url)
    (record-workspace-installers-url workspace-dir installers))

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
                   #:configure configure-args))

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
              '("-N" "raco" "-U" "-l-" "raco" "pkg" "config" "-i" "--set" "default-scope" "installation"))
         (run #:platform platform
              #:compile-any? compile-any?
              `("-N" "raco" "-U" "-l-" "raco" "pkg" "config"
                     "-i" "--set" "name" ,(format "~a-~a-~a~a"
                                                  version
                                                  platform
                                                  vm
                                                  (if compile-any? "-mi" ""))))
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
            (append
             (if addon-dir
                 (list "-A" addon-dir)
                 null)
             (if (equal? command "racket")
                 args
                 (list* "-N" "raco" "-l-" "raco" command args)))))]))
