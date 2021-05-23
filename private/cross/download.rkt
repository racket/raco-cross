#lang racket/base
(require racket/file
         net/url-string
         file/untgz
         version/utils
         "platform.rkt"
         "default.rkt"
         "native.rkt"
         "url.rkt"
         "can-build.rkt")

(provide download-distribution)

;; Downloads and unpacks a distribution named by `platform` and `vm`
;; to `workspace-dir`.

;; The default VM and version are inferred from the currently running
;; Racket (as the same VM and "roudning down" for the version). For a
;; source download, provide `#:platform` as something like
;; "src-builtpkgs" and supply `#:vm` as #f.

;; If `#:zo-dir` is provided (likely within `workspace-dir`), then
;; ".zo" and ".dep" files from there replace the ones in the unpacked
;; distribution; the intent is to replace machine-specific ".zo" files
;; with machine-independent ".zo" files, probably by providing a
;; "builtpkgs".

;; The unpacked directory is moved into place only if all download,
;; unpacking, and ".zo"-replace steps complete.

(define (download-distribution #:workspace workspace-dir
                               #:platform platform ; either arch+OS or "src" or "src-builtpkgs"
                               #:vm [vm (default-vm)] ; use #f for source
                               #:compile-any? [compile-any? #f]
                               #:version [vers (default-version)]
                               #:installers-url [installers (default-installers-url vers)]
                               #:base-name [base-name "racket-minimal"]
                               #:filename [given-filename #f]
                               #:native? [native? #f]
                               #:host [host #f]
                               #:zo-dir [zo-dir #f])
  (define platform+vm (platform+vm->path platform vm #:compile-any? compile-any?))
  (define dest-dir (build-path workspace-dir platform+vm))
  (unless (directory-exists? dest-dir)
    (define tmp-dir (build-path workspace-dir "tmp"))
    (delete-directory/files tmp-dir #:must-exist? #f)
    (make-directory tmp-dir)

    (define filename (or given-filename
                         (string-append base-name "-" vers "-"
                                        (if (and (eq? vm 'bc)
                                                 (valid-version? vers)
                                                 (version<? vers "8.0"))
                                            platform
                                            (platform+vm->path platform vm))
                                        ".tgz")))

    (define url (combine-installers-url installers filename))
    (printf ">> Downloading and unpacking\n ~a\n" (url->string url))
    (define i (open-installer-url url
                                  #:not-found-k
                                  (raise-user-error
                                   (string-append "error: installer not found"
                                                  (if (and native?
                                                           (can-build-platform?))
                                                      "\n consider using `--use-source` to build from source"
                                                      "")))))

    (untgz i #:dest tmp-dir)
    (close-input-port i)

    (define content (directory-list tmp-dir))
    (define one-dir (and (pair? content)
                         (build-path tmp-dir (car content))))
    (unless (and (= 1 (length content))
                 (directory-exists? one-dir))
      (error 'get-distribution
             "expected a single directory inside unpacked archive at ~a"
             tmp-dir))

    (when zo-dir
      (let ([one-dir (path->complete-path one-dir)])
        (parameterize ([current-directory zo-dir])
          (for ([f (in-directory)])
            (when (regexp-match? #rx"[.]zo$" f)
              (when (file-exists? (build-path one-dir f))
                (copy-file f (build-path one-dir f) #t))
              (define dep-f (path-replace-suffix f #".dep"))
              (when (and (file-exists? dep-f)
                         (file-exists? (build-path one-dir dep-f)))
                (copy-file dep-f (build-path one-dir dep-f) #t)))))))

    (when compile-any?
      (define system.rktd (build-path one-dir "lib" "system.rktd"))
      (define sys (call-with-input-file* system.rktd read))
      (call-with-output-file*
       system.rktd
       #:exists 'truncate
       (lambda (o) (writeln (hash-set sys 'target-machine #f) o))))

    (define build-dir (build-path one-dir "build"))
    (make-directory* build-dir)
    (cond
      [native?
       (define p (build-path build-dir as-native-file))
       (call-with-output-file* p #:exists 'truncate void)]
      [host
       (define p (build-path build-dir host-file))
       (call-with-output-file* p #:exists 'truncate
                               (lambda (o)
                                 (write host o)))])

    (rename-file-or-directory one-dir dest-dir)
    (delete-directory tmp-dir)))
