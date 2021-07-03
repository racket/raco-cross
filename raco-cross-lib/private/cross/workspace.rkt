#lang racket/base
(require racket/file
         racket/string)

(provide workspace-version
         record-workspace-version
         workspace-installers-url
         record-workspace-installers-url)

(define (get fn)
  (and (file-exists? fn)
       (string-trim (file->string fn))))

(define (put fn val)
  (unless (file-exists? fn)
    (call-with-output-file*
     fn
     (lambda (o)
       (displayln val o)))))

(define (version-file workspace-dir)
  (build-path workspace-dir "version.txt"))

(define (workspace-version workspace-dir)
  (get (version-file workspace-dir)))

(define (record-workspace-version workspace-dir version)
  (put (version-file workspace-dir) version))


(define (installers-url-file workspace-dir)
  (build-path workspace-dir "installers-url.txt"))

(define (workspace-installers-url workspace-dir)
  (get (installers-url-file workspace-dir)))

(define (record-workspace-installers-url workspace-dir installers-url)
  (put (installers-url-file workspace-dir) installers-url))
