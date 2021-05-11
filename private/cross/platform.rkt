#lang racket/base

(provide host-platform
         source-platform
         platform+vm->path
         platform->machine)

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
                     (string-append "-" vm)
                     "")))

(define (platform->machine platform)
  (define (fail)
    (error 'cross "unrecognized platform: ~s" platform))
  (define m (regexp-match #rx"^([^-]+)-([^-]+)$" platform))
  (cond
    [m (string-append "t"
                      (case (cadr m)
                        [("x86_64") "a6"]
                        [("aarch64") "arm64"]
                        [("i386") "i3"]
                        [else (fail)])
                      (case (caddr m)
                        [("win32") "nt"]
                        [("macosx") "osx"]
                        [("linux") "le"]
                        [("freebsd") "fb"]
                        [("openbsd") "ob"]
                        [("netbsd") "nb"]
                        [else "fail"]))]
    [else (fail)]))
