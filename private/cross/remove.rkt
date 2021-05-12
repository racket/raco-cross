#lang racket/base
(require racket/file
         "platform.rkt"
         "default.rkt")

(provide remove-distribution)

(define (remove-distribution #:workspace workspace-dir
                             #:platform platform
                             #:vm [vm (default-vm)]
                             #:version [vers (default-version)])
  (define platform+vm (platform+vm->path platform vm))
  (define dest-dir (build-path workspace-dir platform+vm))

  (define (xpatch-file mode)
    (build-path workspace-dir
                (platform+vm->path (source-platform) #f)
                "lib"
                (format "~a-xpatch.~a" mode (platform->machine platform))))
 

  (printf ">> Removing ~a\n" platform+vm)
  (unless (or (directory-exists? dest-dir)
              (file-exists? (xpatch-file 'compile))
              (file-exists? (xpatch-file 'library)))
    (printf " nothing to remove\n"))
  
  (delete-directory/files dest-dir #:must-exist? #f)
  (delete-directory/files (xpatch-file 'compile) #:must-exist? #f)
  (delete-directory/files (xpatch-file 'library) #:must-exist? #f))
