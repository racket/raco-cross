#lang racket/base

(provide host-platform
         source-platform
         platform+vm->path
         platform->machine
         normalize-platform)

(define (host-platform)
  (define s (path->string (system-library-subpath #f)))
  (case s
    [("win32\\x86_64") "x86_64-win32"]
    [("win32\\i386") "i386-win32"]
    [else s]))

(define (source-platform)
  "src-builtpkgs")

(define (platform+vm->path platform vm)
  (string-append platform
                 (if vm
                     (string-append "-" (symbol->string vm))
                     "")))

;; Used both to convert to Chez-style machine names
;; and to accept variant spellings
(define (platform->machine platform
                           #:complain-as [complain-as #f])
  (define (fail)
    (if complain-as
        (raise-user-error complain-as
                          "unrecognized platform: "
                          platform)
        (error 'cross "unrecognized platform: ~s" platform)))
  (define m (regexp-match #rx"^([^-]+)-([^-]+)$" platform))
  (cond
    [m (string-append "t"
                      ;; canonical name is first in each case
                      (case (cadr m)
                        [("x86_64" "amd64") "a6"]
                        [("i386" "x86") "i3"]
                        [("aarch64" "arm64") "arm64"]
                        [("arm32" "aarch32") "arm32"]
                        [("ppc" "ppc32" "powerpc" "powerpc32") "ppc32"]
                        [else (fail)])
                      ;; canonical name is first in each case
                      (case (caddr m)
                        [("win32" "win") "nt"]
                        [("macosx" "mac" "macos" "osx") "osx"]
                        [("linux") "le"]
                        [("freebsd") "fb"]
                        [("openbsd") "ob"]
                        [("netbsd") "nb"]
                        [("solaris") "s2"]
                        [else "fail"]))]
    [else (fail)]))

(define (normalize-platform platform
                            #:complain-as [complain-as #f])
  (cond
    [(regexp-match #rx"^t?(a6|i3|arm32|arm64|ppc32)(osx|nt|le|fb|nb|ob|s2)$" platform)
     => (lambda (m)
          (string-append (case (cadr m)
                           [("a6") "x86_64"]
                           [("i3") "i386"]
                           [("arm64") "aarch64"]
                           [("arm32") "arm32"]
                           [("ppc32") "ppc"]
                           [else "oops"])
                         "-"
                         (case (caddr m)
                           [("osx") "macosx"]
                           [("nt") "win32"]
                           [("le") "linux"]
                           [("fb") "freebsd"]
                           [("ob") "openbsd"]
                           [("nb") "netbsd"]
                           [("s2") "solaris"]
                           [else "oops"])))]
    [else
     (normalize-platform (platform->machine platform)
                         #:complain-as complain-as)]))
