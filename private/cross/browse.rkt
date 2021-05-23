#lang racket/base
(require net/url-string
         version/utils
         "url.rkt")

(provide browse-available-platforms)

(define (browse-available-platforms installers
                                    vers
                                    vm)
  (define table-url (combine-installers-url installers "table.rktd"))
  (printf ">> Downloading installers table from\n ~a\n" (url->string table-url))
  (define i (open-installer-url table-url
                                #:not-found-k (lambda ()
                                                (raise-user-error "table of installers not found"))))

  (define (bad-table)
    (raise-user-error "unexpected table format"))
  (define table (with-handlers ([exn:fail:read? (lambda (exn) (bad-table))])
                  (read i)))
  (unless (and (hash? table)
               (for/and ([v (in-hash-values table)])
                 (string? v)))
    (bad-table))
  (close-input-port i)

  (define filename-vers
    (cond
      [(equal? vers "current")
       (define version-url (combine-installers-url installers "version.rktd"))
       (printf ">> Downloading current version\n ~a\n" (url->string version-url))
       (define i (open-installer-url version-url
                                     #:not-found-k (lambda () (raise-user-error "version not found"))))
       (define (bad-version)
         (raise-user-error "unexpected version format"))
       (define vers (with-handlers ([exn:fail:read? (lambda (exn) (bad-table))])
                      (read i)))
       (unless (string? vers)
         (bad-version))
       (close-input-port i)
       vers]
      [else vers]))

  (define-values (lines saw-source?)
    (for/fold ([lines '()] [saw-source? #f]) ([(k v) (in-hash table)])
      (define m (or (regexp-match #rx"^racket-minimal-([^-]+)-(.+)-(bc|cs)[.]tgz$" v)
                    (and (version<? filename-vers "8.0")
                         (regexp-match #rx"^racket-minimal-([^-]+)-((?!src).+)[.]tgz$" v))))
      (values
       (cond
         [m
          (define v-vers (list-ref m 1))
          (define v-platform (list-ref m 2))
          (define v-vm (if (= (length m) 3) 'bc (string->symbol (list-ref m 3))))
          (cond
            [(and m
                  (equal? filename-vers v-vers)
                  (or (not vm) (eq? vm v-vm)))
             (cons (cons (format " ~a~a" v-platform (if vm "" (format " ~a" v-vm)))
                         ;; keep table key for sorting:
                         k)
                   lines)]
            [else lines])]
         [else lines])
       (or saw-source?
           (regexp-match? #rx"^racket-minimal-([^-]+)-src-builtpkgs[.]tgz$" v)))))

  (printf ">> Available for version ~s:\n" vers)
  (when (null? lines)
    (printf " [none]\n"))
  (for ([line (sort lines string<?
                    ;; sort in the same way as a download page:
                    #:key (lambda (p)
                            ;; treat `|` and `;` like a string terminator
                            (regexp-replace* #rx"[;|]" (cdr p) "\0")))])
    (displayln (car line)))

  (unless saw-source?
    (printf "[but source archive not found, which limits support]\n")))
