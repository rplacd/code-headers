;;; code-headers.el --- Navigate code with headers embedded in comments.  -*- mode: Emacs-Lisp; lexical-binding: t; -*

;; Author: Nick Chaiyachakorn <maac.iin.saam@gmail.com>
;; Created: 12 Jul 2012
;; Version: 0.7
;; Keywords: c convenience outlines tools

;; I've put this work in the public domain.
;; Also, try running extract-headers on this file!

(require 'widget)

;;; Commentary:

;; # About this package:

;; Headers are comments that structure the code - bereft of a
;; one-class-per-file limitation, they explain away the structure of a
;; file of code.  They might look something like this:

;; // * Now create the shader program.

;; // (code goes here)

;; // ** Link our attributes to vertex info. 

;; // (code goes here)

;; // * Render!

;; Extract-headers gets their hierarchy and displays it on a buddy
;; buffer, with links to their points in the code. It doesn't do online
;; updating, though, so you'll have to update it as you wish. The point
;; will jump to the buffer when you do this, though. If the buffer's
;; already there when extract-headers is run again, it wipes the buffer
;; and re-uses it.

;; ## How do I use this?

;; Customize *header-starter* and *comment-starter*. Then bind
;; extract-headers or extract-headers-online to a key - and run it. 

;; ## So what's next?

;; If I've got time? A dedicated mode, with navigation keybindings. I
;; figure I'll eventually end up re-creating half of org-mode's
;; functionality, though...

; # Various constants to customize.
; make sure I'm compatible with ;;;... and #pragma **... as well!
(defcustom *comment-starter* ";" 
  "String used to mark the start of a comment line.")
(defun processed-comment-starter ()
  (escape-regexp-input *comment-starter*))
(defcustom *header-starter* "#"
  "String used to mark header depth.")
(defun processed-header-starter ()
  (escape-regexp-input *header-starter*))
;; TODO: escape the above two for regexing
(defcustom *indent-string* "    "
  "String used to increase the depth of a header.")
(defcustom *bullet-string* "- "
  "String used to mark off items on the list. Just a readability thing, really.")

(defconst *buffer-name* "*Structure*")

; # Driver code.
(defun extract-headers ()
  "Extract headers in a buffer, and display it in a separate buffer to the right."
  (interactive)
  (display-headers (rank-headers (slurp-headers (find-header-starts)))))
(defune extract-headers-online ()
  "Extract headers in a buffer and display them without moving focus to the *Structure* buffer. Useful when you're working on a file and just want to scope out its structure"
  (interactive)
  (let ((current-window (selected-window)))
    (extract-headers)
    (select-window current-window)))
(defvar **display-window-that-is-open** nil)
(defun display-headers (mark-rank-text-s)
  (let* ((new-buffer (get-buffer-create *buffer-name*))
         ; if the buffer's already open in a window, re-use it.
         ; otherwise create a new window.
         (new-window (if (get-buffer-window new-buffer)
                         (get-buffer-window new-buffer)
                         (split-window nil -32 "right")))
         ; ASSUMPTION: the currently selected buffer+window is the source.
         (source-buffer (current-buffer))
         (source-window (selected-window)))
    ;; We code generically, whether the required buffer exists or not.
    ; set up emacs...
    (select-window new-window)
    (switch-to-buffer new-buffer)

    ; emulate C-h f or C-h k quit-with-q bindings.
    (local-set-key "q" (lambda () (interactive)
                         (delete-window)))
    ; now edit the buffer we're working with, to add required text...
    (set (make-local-variable 'lexical-binding) 't)
    (preserving-ronly
     (erase-buffer)
     (when (zerop (length mark-rank-text-s))
       (insert "No headers found in buffer."))
     (log mark-rank-text-s)
     (dolist (mark-rank-text mark-rank-text-s)
       (log mark-rank-text)
       (dotimes (%dummy (second mark-rank-text))
         (insert *indent-string*))
       (insert-text-button (concat *bullet-string* (third mark-rank-text))
                           'action (lambda (button)
                                     (select-window source-window)
                                     (switch-to-buffer source-buffer)
                                     (log mark-rank-text)
                                     (goto-char (marker-position (first mark-rank-text)))))      
       (insert "\n")))))

; # Utility definitions.
(defmacro preserving-ronly (&rest body)
  "Wrap forms that modify a buffer in calls that enable and disable read-only mode for that buffer."
   `(progn
      (setq buffer-read-only nil)
      ,@body
      (setq buffer-read-only 't)))
(defun log (data)
  "Log data to *messages*."
  (message "%s" data))
(defun escape-regexp-input (str)
  "Sanitizes input from vars we'll eventually concat into regexes.
   IMPLEMENTATION: adds backslash to . * + ? [ ^ $ \. Simples. 
   Or is it? Emacs regex API is still a bit of a clusterfuck."
  ; I was going to use replace-regexp-in-string, but it's string
  ; replacement behavior is... shonky.
  
  ; Memoize me, please?
  (if (= (length str) 0)
      ""
    (let ((curr-char (aref str 0))
          (rest-string (substring str 1)))
      (if (member curr-char (list ?\. ?\* ?+ ?\? ?\[ ?\^ ?\$ ?\\))
          (concat (string ?\\ curr-char) (escape-regexp-input rest-string))
        (concat (string curr-char) (escape-regexp-input rest-string)))))) 

; # Backend raw-comment-processing phases.
(defun fun ()
  (interactive)
  (log (find-header-starts))
  (log (rank-headers (slurp-headers (find-header-starts)))))
(defun find-header-starts ()
  "Finds all the points where header begin."
  (interactive)
  (let ((regex (concat "^[ \\t]*" 
                       (processed-comment-starter) 
                       "[ \\t]*" 
                       (processed-header-starter) 
                       "+"))
        (matches-so-far ()))
    (save-excursion
      (goto-char (point-min))
      (while (re-search-forward regex nil t)
        (setq matches-so-far (append matches-so-far (list (car (match-data))))))
      matches-so-far)))
(defun slurp-headers (markers)
  "Expand raw header data to full comments heuristically, while preserving marker data for link purposes."
  (mapcar (lambda (marker) (list marker (slurp-header marker)))
          markers))
(defun slurp-header (marker-start)
  "Expands a single marker, to the entire header text. Currently just reads the rest of a header from find-header-starts' match-data by starting at the end of the comment-starter (as opposed to the start of the physical line), and reading to the end of the line and intelligently trimming. We can change this to slurp across multiple lines, but side cases abound."
  (save-excursion
    (goto-char marker-start)
          ;; start after the comment delimiter AND any associated whitespace.
    (let ((start-point (if (re-search-forward (concat "^[ \\t]*" 
                                                      (processed-comment-starter) 
                                                      "[ \\t]*" 
                                                      *header-starter* 
                                                      "+") 
                                              nil t)
                           (marker-position (second (match-data)))
                           marker-position marker-start))
          ;; if we can't find an end to the current line,
          ;; assume the end of the line is the end of the buffer.              
          (end-point (if (re-search-forward "$" nil t)
                          (marker-position (first (match-data)))
                 (point-max))))
      (buffer-substring start-point
                        end-point))))
(defun rank-headers (marker-and-text)
  "Augment list of headers and text with header depth info."
  (mapcar (lambda (m-and-t)
            (list (first m-and-t)
                  (rank-header-depth m-and-t)
                  (second m-and-t)))
          marker-and-text))
(defun rank-header-depth (m-and-t)
  "Find the depth of the current hader - indicated by how many of *header-starter* there is after the *comment-starter* and any gaps inbetween."
  ; Impl: find the first match of header-marker+, find length by
  ; subtracting start marker from end marker.
  (save-excursion 
    (goto-char (first m-and-t))
    (if (re-search-forward (concat (processed-header-starter) "+")) ;; assume
        ;; this succeeds - otherwise we wouldn't have caught this at
        ;; the start, right?
        (let ((start (first (match-data)))
              (end (second (match-data))))
          (1- (- (marker-position end)
                 (marker-position start))))
        0)))
;;; code-headers.el ends here
