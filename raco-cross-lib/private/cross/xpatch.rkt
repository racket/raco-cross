#lang racket/base
(require racket/file
         racket/port
         racket/system
         "host-racket.rkt"
         "platform.rkt")

(provide generate-xpatch)

;; Given an unpacked source directory, an unpacked host Racket directory,
;; and a machine type, writes "compile-xpatch.<mach>" and "library-xpatch.<mach>"
;; to the source directory's "lib" directory.

(define (generate-xpatch #:src-dir src-dir
                         #:host-racket-dir host-dir
                         #:machine machine
                         #:host-machine host-machine)
  (define tmp-xpatch.mach
    (build-path src-dir "lib" (format "tmp-xpatch.~a" machine)))
  (define compile-xpatch.mach
    (build-path src-dir "lib" (format "compile-xpatch.~a" machine)))
  (define library-xpatch.mach
    (build-path src-dir "lib" (format "library-xpatch.~a" machine)))

  (unless (and (file-exists? compile-xpatch.mach)
               (file-exists? library-xpatch.mach))

    (printf ">> Generating cross compiler for ~a\n" machine)

    ;; Compile Scheme source by (ab)using the `--cross-serve` mode of
    ;; a `racket` executable to get a Chez Scheme instance that is not
    ;; tainted by Racket configuration or setup. The `--cross-serve`
    ;; flag wants two files to load; one would be enough for our purposes,
    ;; but we can make two easily enough. One of the files has to define
    ;; `serve-cross-compile` to make `--cross-serve` happy.

    (make-directory* (build-path src-dir "lib"))

    (define dir (build-path src-dir "src" "ChezScheme"))

    (define arch
      (let ([m (regexp-replace "^t" machine "")])
        (cond
          [(regexp-match? #rx"^a6" m) "a6"]
          [(regexp-match? #rx"^i3" m) "i3"]
          [(regexp-match? #rx"^arm64" m) "arm64"]
          [(regexp-match? #rx"^arm32" m) "arm32"]
          [(regexp-match? #rx"^ppc32" m) "ppc32"]
          [else (error "unknown architecture for" machine)])))

    ;; ----------------------------------------
    ;; Extract relevant sources from makefiles

    (define (read-zuo build.zuo)
      (and (file-exists? build.zuo)
           (call-with-input-file*
            build.zuo
            #:mode 'text
            (lambda (i)
              (unless (equal? (read-line i) "#lang zuo")
                (error "expected `#lang zuo`from build.zuo"))
              (let loop ()
                (define v (read i))
                (if (eof-object? v)
                    null
                    (cons v (loop))))))))
    (define s/build.zuo
      (read-zuo (build-path dir "s" "build.zuo")))
    (define cs/c/build.zuo
      (read-zuo (build-path src-dir "src" "cs" "c" "build.zuo")))
    
    (define mf-base (and (not s/build.zuo)
                         (let ([s (file->string (build-path dir "s" "Mf-base"))])
                           (string-append "\n" (regexp-replace* "\\\\\n" s "")))))
    (define Makefile.in (and (not cs/c/build.zuo)
                             (let* ([s (file->string (build-path src-dir "src" "cs" "c" "Makefile.in"))]
                                    [s (regexp-replace* "\\\\\n" s "")]
                                    [s (regexp-replace* "[$][(]([A-Za-z_]+)[)]" s "\\1")])
                               (string-append "\n" s))))

    (define (get-zuo-sources name content #:suffix [suffix #".ss"])
      (or (for/or ([e (in-list content)])
            (and (list? e)
                 (= 3 (length e))
                 (eq? 'define (car e))
                 (eq? name (cadr e))
                 (let ([rhs (caddr e)])
                   (and (list? rhs)
                        (eq? 'list (car rhs))
                        (map (lambda (p) (path->string (path-replace-suffix p suffix))) (cdr rhs))))))
          (error "not found:" name)))

    (define (get-makefile-srcs id mkfile #:suffix [suffix #".ss"])
      (let ([m (regexp-match (format "\n~a *= *([^\n]*)" id) mkfile)])
        (unless m (error 'xpatch "could not find `~a`" id))
        (for/list ([sym (in-list (read (open-input-string (string-append "(" (cadr m) ")"))))])
          (path->string (path-replace-suffix (symbol->string sym) suffix)))))

    (define macro-srcs (if s/build.zuo
                           (get-zuo-sources 'macro-src-names s/build.zuo)
                           (get-makefile-srcs 'macroobj mf-base)))
    (define compile-srcs (if s/build.zuo
                             (get-zuo-sources 'patch-names s/build.zuo)
                             (get-makefile-srcs 'patchobj mf-base)))
    (define library-srcs (if cs/c/build.zuo
                             (get-zuo-sources 'library-xpatch-names cs/c/build.zuo #:suffix #".sls")
                             (get-makefile-srcs 'RACKET_XPATCH Makefile.in #:suffix #".sls")))

    ;; Instantiate "machine.def" in the Chez Scheme source area, like `configure`
    ;; or `workarea` would do in a normal build
    (cond
      [(file-exists? (build-path dir "s" (format "~a.def" machine)))
       (copy-file (build-path dir "s" (format "~a.def" machine))
                  (build-path dir "s" "machine.def")
                  #t)]
      [else
       (call-with-input-file*
        (build-path dir "s" "tunix.def")
        (lambda (i)
          (call-with-output-file*
           (build-path dir "s" "machine.def")
           #:exists 'truncate
           (lambda (o)
             (let loop ()
               (define l (read-line i))
               (unless (eof-object? l)
                 (displayln (let* ([l (regexp-replace* #rx"[$][(]M[)]" l machine)]
                                   [l (regexp-replace* #rx"[$][(]March[)]" l arch)]
                                   [l (regexp-replace* #rx"[$][(]Mtimet[)]" l
                                                       (cond
                                                         [(regexp-match? #rx"(nb|ob)$" machine)
                                                          "64"]
                                                         [(or (string=? arch "i3")
                                                              (string=? arch "ppc32")
                                                              (string=? arch "arm32"))
                                                          "32"]
                                                         [else "64"]))])
                              l)
                            o)
                 (loop)))))))])

    ;; ----------------------------------------

    ;; Compile cross-serve.ss

    (define exit-on-error '(base-exception-handler (lambda (x)
                                                     (let ([e (current-error-port)])
                                                       (display-condition x e)
                                                       (newline e))
                                                     (exit 1))))

    (call-with-output-file*
     (build-path src-dir "src" "cs" "c" "xscript1.ss")
     #:exists 'truncate
     (lambda (o)
       (writeln exit-on-error o)
       (writeln `(define (serve-cross-compile machine)
                   (void))
                o)
       (writeln `(command-line-arguments '("."
                                           "cross-serve.ss"
                                           "../expander/env.ss"))
                o)))

    (parameterize ([current-directory (build-path src-dir "src" "cs" "c")])
      (unless (system* (find-host-racket host-dir)
                       "--cross-server"
                       machine
                       "xscript1.ss"
                       "mk-cross-serve.ss")
        (error "compile failed")))
    
    ;; ----------------------------------------
    
    ;; This is the code to run in Chez Scheme to build Chez Scheme's
    ;; compiler as a cross-compilation "patch" (i.e., the content of
    ;; "compiler-xpatch.<mach>")
    (define code-to-run
      `(begin
         ,exit-on-error
         (define compile-one
           (lambda (dir src dest lib? load?)
             (parameterize ([current-directory (or dir
                                                   (current-directory))])
               (subset-mode 'system)
               (if lib?
                   (compile-library src dest)
                   (compile-file src dest))
               (subset-mode #f)
               (when load?
                 (load dest)))))

         ;; compiling in unsafe mode:
         (optimize-level 3)
         (debug-level 0)

         ,@(let ()
             (define (compile-one s
                                  #:dest [dest (path-replace-suffix s #".so")]
                                  #:lib? [lib? #f]
                                  #:load? [load? #f]
                                  #:dir [dir #f])
               `(compile-one ,(if (path? dir) (path->string dir) dir)
                             ,(if (path? s) (path->string s) s)
                             ,(if (path? dest) (path->string dest) dest)
                             ,lib?
                             ,load?))
             (define (compile-macro s)
               (compile-one s #:load? #t))
             
             (cons
              (compile-one "nanopass.ss"
                           #:lib? #t
                           #:dest "../s/nanopass.so"
                           #:dir "../nanopass")
              (append
               (map compile-macro macro-srcs)
               (map compile-one compile-srcs))))))

    (call-with-output-file*
     (build-path dir "s" "xscript1.ss")
     #:exists 'truncate
     (lambda (o) (writeln code-to-run o)))

    (call-with-output-file*
     (build-path dir "s" "xscript2.ss")
     #:exists 'truncate
     (lambda (o) (writeln `(define (serve-cross-compile machine)
                             (void))
                          o)))

    (parameterize ([current-directory (build-path dir "s")])
      (unless (system* (find-host-racket host-dir)
                       "--cross-server"
                       machine
                       "xscript1.ss"
                       "xscript2.ss")
        (error "compile failed")))

    ;; ----------------------------------------

    (define (copy-file-to-port f o)
      (call-with-input-file*
       f
       (lambda (i)
         (copy-port i o))))

    (define xpatch (build-path dir "xpatch"))
    
    ;; Combine to generate the compiler patch:
    (call-with-output-file*
     xpatch
     #:exists 'truncate
     (lambda (o)
       (for ([s (in-list compile-srcs)])
         (copy-file-to-port
          (build-path dir "s" (path-replace-suffix s #".so"))
          o))))

    (call-with-output-file*
     tmp-xpatch.mach
     #:exists 'truncate
     (lambda (o)
       (copy-file-to-port
        (build-path src-dir "src" "cs" "c" "cross-serve.so")
        o)
       (copy-file-to-port xpatch o)))

    ;; Only create compile-xpatch.mach if everything succeeds to this point
    (rename-file-or-directory tmp-xpatch.mach compile-xpatch.mach #t)

    ;; ----------------------------------------

    (define host-suffix (string->bytes/utf-8
                         (string-append "." host-machine)))

    (define (make-library-script src deps)
      (call-with-output-file*
       (build-path src-dir "src" "cs" "xscript1.ss")
       #:exists 'truncate
       (lambda (o)
         (writeln exit-on-error o)
         (writeln `(define (serve-cross-compile machine)
                     (void))
                  o)
         (writeln `(command-line-arguments
                    (list ,@(append (list "--unsafe"
                                          "--xpatch"
                                          "../ChezScheme/xpatch"
                                          src)
                                    (if s/build.zuo
                                        (list (path->string (path-replace-suffix src ".so")))
                                        null)
                                    (for/list ([dep (in-list deps)])
                                      (path->string (path-replace-suffix dep host-suffix))))))
                  o)
         (writeln `(printf "compiling ~s\n" ,src)
                  o))))

    (define (compile-library src deps)
      (make-library-script src deps)
      (parameterize ([current-directory (build-path src-dir "src" "cs")])
        (unless (system* (find-host-racket host-dir)
                         "--cross-server"
                         machine
                         "xscript1.ss"
                         "compile-file.ss")
          (error "failed"))))
    
    
    (let loop ([library-srcs library-srcs] [deps '()])
      (unless (null? library-srcs)
        (compile-library (car library-srcs) deps)
        (loop (cdr library-srcs)
              (append deps (list (car library-srcs))))))
    
    ;; Combine to generate the library patch:
    (call-with-output-file*
     tmp-xpatch.mach
     #:exists 'truncate
     (lambda (o)
       (for ([s (in-list library-srcs)])
         (copy-file-to-port
          (build-path src-dir "src" "cs" (path-replace-suffix s host-suffix))
          o))))

    (rename-file-or-directory tmp-xpatch.mach library-xpatch.mach #t)

    (void)))
