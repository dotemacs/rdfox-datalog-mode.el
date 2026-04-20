;;; rdfox-datalog-mode.el --- Major mode for editing RDFox Datalog files -*- lexical-binding: t; -*-

;; Author: Aleksandar Simic <a@repl.ist>
;; Keywords: languages, convenience
;; Version: 0.1.0

;; This file is NOT part of GNU Emacs.

;;; Commentary:
;;
;; A major mode for editing .dlog files.
;;
;; Features:
;; - Syntax highlighting for RDFox Datalog keywords, built-ins, variables,
;;   IRIs, literals, and operators.
;; - # comments.
;; - Basic indentation.
;; - Automatic activation for .dlog files.

;;; Code:

(require 'rx)

(defgroup rdfox-datalog nil
  "Major mode for RDFox Datalog files."
  :group 'languages)

(defcustom rdfox-datalog-indent-offset 2
  "Indentation width for `rdfox-datalog-mode'."
  :type 'integer
  :group 'rdfox-datalog)

(defconst rdfox-datalog--keywords
  '("PREFIX" "NOT" "EXIST" "EXISTS" "IN" "FILTER" "BIND" "AS" "AGGREGATE" "ON"
    "COUNT" "MIN" "MAX" "SUM" "AVG" "DISTINCT")
  "Datalog keywords understood by the parser package.")

(defconst rdfox-datalog--builtins
  '("CONCAT" "STR" "IF" "IRI" "SKOLEM" "ROUND" "REGEX")
  "Built-in RDFox Datalog function names.")

(defconst rdfox-datalog-font-lock-keywords
  `((,(rx symbol-start (regexp (regexp-opt rdfox-datalog--keywords t)) symbol-end)
     . font-lock-keyword-face)
    (,(rx symbol-start (regexp (regexp-opt rdfox-datalog--builtins t)) symbol-end)
     . font-lock-builtin-face)
    (,(rx symbol-start (or "true" "false") symbol-end)
     . font-lock-constant-face)
    (,(rx "?" (one-or-more (or word ?_)))
     . font-lock-variable-name-face)
    (,(rx "_:" (one-or-more (or word ?_)))
     . font-lock-constant-face)
    (,(rx "<" (zero-or-more (not (any "\n" ">"))) ">")
     . font-lock-constant-face)
    (,(rx symbol-start
          (one-or-more (or word ?_))
          ":"
          (one-or-more (or word ?_))
          symbol-end)
     . font-lock-constant-face)
    (,(rx symbol-start
          (or ":"
              (seq (one-or-more (or word ?_)) ":"))
          symbol-end)
     . font-lock-constant-face)
    (,(rx ":" (one-or-more (or word ?_)))
     . font-lock-constant-face)
    (,(rx (or ":-" "!=" "<=" ">=" "&&" "||"))
     . font-lock-keyword-face)
    (,(rx symbol-start
          (optional (any "+" "-"))
          (one-or-more digit)
          (optional "." (zero-or-more digit))
          (optional (any "e" "E") (optional (any "+" "-")) (one-or-more digit))
          symbol-end)
     . font-lock-constant-face))
  "Font lock rules for `rdfox-datalog-mode'.")

(defvar rdfox-datalog-mode-syntax-table
  (let ((st (make-syntax-table)))
    ;; # comments
    (modify-syntax-entry ?# "<" st)
    (modify-syntax-entry ?\n ">" st)

    ;; Strings
    (modify-syntax-entry ?\" "\"" st)
    (modify-syntax-entry ?' "\"" st)

    ;; Word constituents for common Datalog tokens.
    (modify-syntax-entry ?? "_" st)
    (modify-syntax-entry ?_ "w" st)
    (modify-syntax-entry ?: "_" st)
    st)
  "Syntax table for `rdfox-datalog-mode'.")

(defun rdfox-datalog-syntax-propertize (start end)
  "Prevent comment syntax from applying to # inside IRI refs between START and END."
  (save-excursion
    (goto-char start)
    (remove-text-properties start end '(syntax-table nil))
    (while (re-search-forward "<[^>\n]*>" end t)
      (let ((iri-start (match-beginning 0))
            (iri-end (match-end 0)))
        (save-excursion
          (goto-char iri-start)
          (while (search-forward "#" iri-end t)
            (put-text-property (1- (point))
                               (point)
                               'syntax-table
                               (string-to-syntax "."))))))))

(defun rdfox-datalog--previous-significant-line ()
  "Move point to previous non-empty, non-comment line.
Return point if found, otherwise nil."
  (catch 'found
    (while (zerop (forward-line -1))
      (back-to-indentation)
      (unless (or (eolp) (looking-at-p "#"))
        (throw 'found (point))))
    nil))

(defun rdfox-datalog--line-starts-with-closing-delimiter-p ()
  "Return non-nil if current line starts with a closing delimiter or terminal dot."
  (save-excursion
    (back-to-indentation)
    (looking-at-p (rx (or ")" "]" ".")))))

(defun rdfox-datalog--previous-line-opens-body-p ()
  "Return non-nil if the previous significant line opens a continuation block."
  (save-excursion
    (when (rdfox-datalog--previous-significant-line)
      (end-of-line)
      (skip-chars-backward " \t")
      (or (looking-back ":-" (line-beginning-position))
          (looking-back "[][(),]$" (line-beginning-position))
          (looking-back ",$" (line-beginning-position))))))

(defun rdfox-datalog-compute-indentation ()
  "Compute indentation for the current line."
  (save-excursion
    (back-to-indentation)
    (cond
     ((bobp) 0)
     ((rdfox-datalog--line-starts-with-closing-delimiter-p)
      (when (ignore-errors (backward-up-list) t)
        (current-indentation)))
     ((rdfox-datalog--previous-line-opens-body-p)
      (+ (save-excursion
           (rdfox-datalog--previous-significant-line)
           (current-indentation))
         rdfox-datalog-indent-offset))
     (t
      (or (save-excursion
            (when (rdfox-datalog--previous-significant-line)
              (current-indentation)))
          0)))))

(defun rdfox-datalog-indent-line ()
  "Indent current line for `rdfox-datalog-mode'."
  (interactive)
  (let ((indent (rdfox-datalog-compute-indentation))
        (offset (- (current-column) (current-indentation))))
    (indent-line-to (max indent 0))
    (when (> offset 0)
      (move-to-column (+ indent offset)))))

;;;###autoload
(define-derived-mode rdfox-datalog-mode prog-mode "RDFox-Datalog"
  "Major mode for editing RDFox Datalog files."
  :syntax-table rdfox-datalog-mode-syntax-table
  (setq-local font-lock-defaults '(rdfox-datalog-font-lock-keywords))
  (setq-local syntax-propertize-function #'rdfox-datalog-syntax-propertize)
  (setq-local comment-start "#")
  (setq-local comment-end "")
  (setq-local indent-line-function #'rdfox-datalog-indent-line)
  (setq-local indent-tabs-mode nil))

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.dlog\\'" . rdfox-datalog-mode))

(provide 'rdfox-datalog-mode)

;;; rdfox-datalog-mode.el ends here
