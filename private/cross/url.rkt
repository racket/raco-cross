#lang racket/base
(require net/url
         racket/list)

(provide combine-installers-url
         open-installer-url)

(define (combine-installers-url installers filename)
  (combine-url/relative (url->directory-url
                         (if (string? installers)
                             (string->url installers)
                             installers))
                        filename))

(define (url->directory-url u)
  (case (url-scheme u)
    [("file")
     (path->url (path->directory-path (url->path u)))]
    [else
     (define p (url-path u))
     (cond
       [(or (empty? p)
            (string=? "" (path/param-path (last p))))
        u]
       [else
        (struct-copy url u
                     [path (append p (list (path/param "" null)))])])]))

(define (open-installer-url url #:not-found-k not-found-k)
  (case (url-scheme url)
    [("file")
     (open-input-file (url->path url))]
    [else
     (define-values (i headers) (get-pure-port/headers url
                                                       #:redirections 5
                                                       #:status? #t))
     (define status (string->number (substring headers 9 12)))
     (case status
       [(200) (void)]
       [(404 410)
        (close-input-port i)
        (not-found-k)]
       [else
        (define msg (read-string 4096 i))
        (close-input-port i)
        (raise-user-error "error on download" msg)])
     i]))
