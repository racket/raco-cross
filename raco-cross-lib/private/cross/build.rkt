#lang racket/base
(require racket/file
         racket/system
         "platform.rkt"
         "default.rkt"
         "native.rkt"
         "can-build.rkt")

(provide build-host)

(define (build-host #:workspace workspace-dir
                    #:platform platform ; arch+OS
                    #:vm [vm (default-vm)]
                    #:configure [configure-args '()])
  (unless (can-build-platform?)
    (raise-user-error "building from source currently works only on Unix-like platforms"))

  (define platform+vm (platform+vm->path platform vm))
  (define dest-dir (build-path workspace-dir platform+vm))
  (unless (directory-exists? dest-dir)
    (printf ">> Building for host from source\n")

    (define src-dir (build-path workspace-dir (platform+vm->path (source-platform) #f)))
    (define tmp-dir (build-path workspace-dir "host-build"))

    (delete-directory/files tmp-dir #:must-exist? #f)
    (copy-directory/files src-dir tmp-dir
                          #:keep-modify-seconds? #t
                          #:preserve-links? #t)

    (define has-cs? (directory-exists? (build-path tmp-dir "src" "cs")))
    (when (and (eq? vm 'cs)
               (not has-cs?))
      (raise-user-error "CS cannot be built for this version"))

    (define build-note-dir (build-path tmp-dir "build"))
    (make-directory* build-note-dir)
    (call-with-output-file* (build-path build-note-dir as-native-file) #:exists 'truncate void)

    (make-directory* (build-path tmp-dir "src" "build"))
    (parameterize ([current-directory (build-path tmp-dir "src" "build")])
      (define sh (or (find-executable-path "sh")
                     "sh"))
      (define make (or (find-executable-path "gmake")
                       (find-executable-path "make")
                       "make"))
      (unless (and
               (apply system*
                      sh
                      "../configure"
                      (append (case vm
                                [(cs) '("--enable-csdefault")]
                                [(bc) (if has-cs?
                                          '("--enable-bcdefault")
                                          null)])
                              configure-args))
               (system* make)
               (system* make "install"))
        (raise-user-error (string-append
                           "build failed\n"
                           " If you repair manually and make the build work at\n"
                           (format "  ~a\n" tmp-dir)
                           " with `configure, `make`, and `make install` steps,\n"
                           " then rename that directory to\n"
                           (format "  ~a\n" dest-dir)))))

    (rename-file-or-directory tmp-dir dest-dir)))
