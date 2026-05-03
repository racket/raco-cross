#lang racket/base
(require racket/cmdline
         raco/command-name
         racket/file
         "default.rkt"
         "platform.rkt"
         "main.rkt")

(define version #f)
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

 (apply raco-cross
        #:version version
        #:workspace-dir workspace-dir
        #:installers-url installers-url
        #:archive download-filename
        #:vm vm
        #:base-name base-name
        #:host host
        #:target target
        #:native? native?
        #:skip-setup? skip-setup?
        #:skip-pkgs? skip-pkgs?
        #:jobs jobs
        #:compile-any? compile-any?
        #:use-source? use-source?
        #:configure-args (reverse rev-configure-args)
        #:quiet? quiet?
        #:remove? remove?
        #:browse? browse?
        #:command command
        arg))

(module test racket/base)
