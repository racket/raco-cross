#lang racket/base
(require "private/platform.rkt"
         "private/download.rkt"
         "private/setup.rkt"
         "private/xpatch.rkt"
         "private/run.rkt")

(download-distribution #:workspace "/tmp/cross"
                       #:platform (source-platform)
                       #:vm #f)

(download-distribution #:workspace "/tmp/cross"
                       #:platform (host-platform))

(download-distribution #:workspace "/tmp/cross"
                       #:platform "x86_64-macosx"
                       #:zo-dir "/tmp/cross/src-builtpkgs")

(setup-distribution #:workspace "/tmp/cross"
                    #:platform "x86_64-macosx")

(run-cross-racket #:workspace "/tmp/cross"
                  #:platform "x86_64-macosx"
                  "-l-"
                  "raco"
                  "pkg"
                  "install"
                  "--installation"
                  "--skip-installed"
                  "compiler-lib")

(run-cross-racket #:workspace "/tmp/cross"
                  #:platform "x86_64-macosx"
                  "-l-"
                  "raco"
                  "make"
                  "/tmp/hello.rkt")

(run-cross-racket #:workspace "/tmp/cross"
                  #:platform "x86_64-macosx"
                  "-l-"
                  "raco"
                  "exe"
                  "/tmp/hello.rkt")

