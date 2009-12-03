;;; sigbegone.el -- exorcize annoying isp ads and other sigs from emails

;; Copyright (C) 2001 - 2005 Neil W. Van Dyke

;; Author:   Neil W. Van Dyke <neil@neilvandyke.org>
;; Version:  0.11
;; X-URL:    http://www.neilvandyke.org/sigbegone/
;; X-CVS:    $Id: sigbegone.el,v 1.107 2005/03/15 12:16:04 neil Exp $ GMT

;; This is free software; you can redistribute it and/or modify it under the
;; terms of the GNU General Public License as published by the Free Software
;; Foundation; either version 2, or (at your option) any later version.  This
;; is distributed in the hope that it will be useful, but without any warranty;
;; without even the implied warranty of merchantability or fitness for a
;; particular purpose.  See the GNU General Public License for more details.
;; You should have received a copy of the GNU General Public License along with
;; Emacs; see the file `COPYING'.  If not, write to the Free Software
;; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307, USA.")

;;; Commentary:

;; INTRODUCTION:
;;
;;   `sigbegone.el' can be used to visually de-emphasize email sigs, especially
;;   the advertisements appended to messages by some free email account
;;   providers.

;; SYSTEM REQUIREMENTS:
;;
;;   The `sigbegone.el' package was written using FSF GNU Emacs 21 on a
;;   GNU/Linux system, and should work with recent Emacs versions on Unix
;;   variants.  `sigbegone.el' has not been tested with the XEmacs fork of
;;   Emacs, and I'd welcome any necessary patches.
;;
;;   `sigbegone.el' has special support for the VM email reader package
;;   (`http://www.wonderworks.com/vm/', tested with version 7.19) by Kyle
;;   E. Jones, and Gnus news and mail reader (`http://www.gnus.org/', very
;;   minimally tested with version 5.9.0) by Lars Magne Ingebrigtsen.  Neither
;;   of those packages is required to use `sigbegone.el', however.

;; INSTALLATION:
;;
;;   1. Put this `sigbegone.el' file somewhere in your Emacs Lisp load path.
;;
;;   2. Add the following to your `.emacs' file (or elsewhere):
;;
;;          (require 'sigbegone)
;;
;;   3. After either restarting Emacs or loading the package, do:
;;
;;          M-x sigbegone-customize RET
;;
;;      and adjust the options however you like.
;;
;;   4. If you want to exorcize sigs in Emacs programs other than VM or Gnus,
;;      arrange for the function `sigbegone-exorcize-buffer' to be called
;;      whenever your program displays a new message in a buffer.  You may also
;;      wish to bind `sigbegone-denounce-from-point' to a key or menu item for
;;      the buffer.

;; HOW TO USE IT:
;;
;;   By default, many sigs shown in your VM mail reader (or whatever program
;;   you hooked up to `sigbegone-exorcize-buffer') should be displayed in a
;;   barely-readable color.  These sigs are known as "exorcized."  If you
;;   desire to read an exorcised sig, you can move the mouse over it to make it
;;   temporarily appear in a more visible color.
;;
;;   To cause `sigbegone.el' to exorcize a sig that it does not currently
;;   exorcize, you "denounce" the sig by positioning the point somewhere on the
;;   first line of the sig (or on a preceding blank line), and invoking
;;   `sigbegone-denounce-from-point' (which by default is bound to [C-c C-s] in
;;   VM.  The sig will be highlighted in white-on-red while you are prompted
;;   "Denounce the highlighted sig? (y or n)".
;;
;;   `sigbegone.el' uses the `custom' facility of Emacs to store both normal
;;   options and also a list of the sigs that you've denounced in the past.

;;; Change Log:

;; Version 0.11 (2005-03-15) Rules additions.
;;
;; Version 0.10 (2004-11-23) Rules additions and changes.
;;
;; Version 0.9 (2004-03-30) Rules additions.
;;
;; Version 0.8 (2004-01-02) Rules additions.
;;
;; Version 0.7 (2003-10-27) Rules additions.
;;
;; Version 0.6 (2003-06-28) Rules additions.
;;
;; Version 0.5 (2003-05-22) Rules improvements.
;;
;; Version 0.4 (2003-05-07) More rules.
;;
;; Version 0.3 (2002-10-15) Updated email address.
;;
;; Version 0.2 (2001-02-09) Added simple Gnus support.  (I don't use Gnus
;; heavily, so please let me know if you notice that it doesn't work with
;; certain combinations of Gnus features.)  Fixed free variable.
;;
;; Version 0.1 (2001-01-29) Initial release.

;;; Code:

(require 'custom)
(require 'cus-edit)

;; Customization:

(defgroup sigbegone nil
  "Exorcize annoying ISP ads and other sigs from emails."
  :group  'mail
  :prefix "sigbegone-")

(defcustom sigbegone-exorcize-minusminusspace-sigs-p t
  "Should conventional `^-- \\n' sigs be exorcized?
Note that you want this *on* if your `sigbegone' intent is to de-emphasize
*all* sigs; you want this off if you use `sigbegone' to de-emphasize only
commercial advertisement sigs and such."
  :group      'sigbegone
  :type       'boolean
  :set        'sigbegone-custom-set
  :initialize 'custom-initialize-default)

(defcustom sigbegone-define-vm-keys-p t
  "Should the VM mail reader keymaps be modified?"
  :group 'sigbegone
  :type  'boolean)

(defcustom sigbegone-define-gnus-keys-p t
  "Should the Gnus news and mail reader keymaps be modified?"
  :group 'sigbegone
  :type  'boolean)

(defcustom sigbegone-exorcize-search-distance 1000
  "Maximum distance in characters from end of buffer in which to match sig."
  :group 'sigbegone
  :type  'integer)

(defface sigbegone-exorcized-face
  '((((class color) (background light))
     (:foreground "gray85" :bold nil :inverse-video nil :italic nil
                  :underline nil))
    (((class color) (background dark))
     (:foreground "gray15" :bold nil :inverse-video nil :italic nil
                  :underline nil))
    (t (:italic t :underline nil)))
  "Face used for exorcized sigs."
  :group 'sigbegone)

(defface sigbegone-exorcized-mouse-face
  '((((class color) (background light))
     (:foreground "gray55" :bold nil :inverse-video nil :italic nil
                  :underline nil))
    (((class color) (background dark))
     (:foreground "gray45" :bold nil :inverse-video nil :italic nil
                  :underline nil))
    (t (:italic nil :underline nil)))
  "Face used when the mouse is over an exorcized sig."
  :group 'sigbegone)

(defface sigbegone-denounce-face
  '((((class color) (background light))
     (:foreground "white" :background "red4"))
    (((class color) (background dark))
     (:foreground "white" :background "red"))
    (t              (:inverse-video t)))
  "Face used for temporary indicating a sig during denouncement."
  :group 'sigbegone)

(defcustom sigbegone-manual-rules
  (list 
   (concat "\\(_____*\\|-----*\\|=====*\\)[ \t]*\r?\n"
           "\\([ \t]*\r?\n\\)?"
           (regexp-opt
            '("add msn 8 internet software to your current internet"
              "add photos to your e-mail with"
              "add photos to your messages with"
              "attachments are virus free"
              "chat with friends online, try"
              "check out msn pc safety & security to help ensure your pc is"
              "check out the coupons and bargains on"
              "choose now from 4 levels of"
              "disclaimer"
              "do you yahoo"
              "don't know which one to"
              "e-groups home"
              "e-groups.com home"
              "e-mail disclaimer"
              "egroups home"
              "egroups.com home"
              "email disclaimer"
              "enjoy a special introductory offer for dial-up internet access"
              "for the fastest and easiest way"
              "free"
              "get free"
              "get gobivisto"
              "get internet access from"
              "get rid of annoying pop-up ads with the new"
              "get your"
              "got questions"
              "help stop spam with the new"
              "if you wish to be removed from this list"
              "is your pc infected? get a free online computer virus scan"
              "join the world's largest e-mail service with"
              "join the world=92s largest e-mail service with"
              "join the world\222s largest e-mail service with"
              "learn how to help protect your privacy and prevent fraud online"
              "looking to buy a house? get informed with the home buying"
              "mail2web - check your email from the web at"
              "make your home warm and cozy this winter with tips from"
              "msn 8 helps eliminate e-mail viruses"
              "msn 8 with e-mail virus protection"
              "msn messenger  http://g.msn.fr/fr1001/866 : un logiciel gratuit"
              "msn messenger : discutez en direct avec vos amis"
              "msn photos is the easiest way to share and print your photos"
              "my inbox is protected by spamfighter"
              "never get a busy signal because you are always connected"
              "on the road to retirement? check out msn life events for"
              "posted via pinpost"
              "protect your pc - get"
              "search the web with google from any site.  download the free"
              "send and receive hotmail on your mobile device"
              "send instant messages to anyone on your contact list with"
              "sf email is sponsored by -"
              "stop more spam with the new"
              "stop worrying about overloading your inbox - get"
              "surf the web without missing calls! get"
              "the new msn"
              "this message is coming to you from"
              "this message was posted"
              "this message was powered"
              "this message was remailed to you via"
              "this message was sent using imp"
              "this sf.net email is sponsored by"
              "this sf.net email sponsored by"
              "tired of spam? get advanced junk mail protection with"
              "to unsubscribe"
              "use custom emotions -- try"
              "watch high-quality video with fast playback at"
              "watch live baseball games on your computer with"
              "worried about inbox overload? get"
              "you're paying too much")
            t)
           "\\([ ?!.,:].*\\|[ \t]+\\)?"
           "\\(\r?\n.*\\)*")
   (concat "get your free email and voicemail at .* http://.*"
           "\\(\r?\n.*\\)*")
   (concat "sent via deja\\.com[ \n]http://www\\.deja\\.com/[ \t]*"
           "\\(\r?\nbefore you buy\\.\\)"
           "\\(\r?\n.*\\)*")
   (concat " *-----= posted via newsfeeds?\\.com.*"
           "\\(\r?\n.*\\)*")
   ;; TODO: Merge this with first rule.
   (concat "\\(_____*\\|-----*\\|=====*\\)[ \t]*\r?\n"
           "[-a-z]+ mailing list\r?\n"
           "[-a-z]+@\\(gnu\\.org\\|lists\\.sourceforge\\.net\\)"
           "\\(\r?\n.*\\)*"))
  "List of hand-crafted regexps for matching sigs to exorcize.
These are in addition to regexps that are generated to match
`sigbegone-examples'.  A `^' will effectively be prepended before each regexp
before evaluation, but should not be included here.  Regexps should not match
trailing whitespace at the end of the sig.  (Please note that allusion to
organizations or products in the default value of this option should not be
construed as endorsement or condemnation -- the author simply found these
regexps helpful in eliminating subjectively-perceived crud, and is providing
them for purposes of demonstrating the operation of this tool, and perhaps as
useful defaults.)"
  :group      'sigbegone
  :type       '(repeat regexp)
  :set        'sigbegone-custom-set
  :initialize 'custom-initialize-default)

(defcustom sigbegone-examples
  '()
  "You normally don't want to edit this.
List of sigs that have been denounced via `sigbegone-denounce-from-point'."
  :group      'sigbegone
  :type       '(repeat string)
  :set        'sigbegone-custom-set
  :initialize 'custom-initialize-default)

;; Constants:

(defconst sigbegone-whitespace-char-regexp "[ \t\r\n\v\f]")

;; Non-Option Global Variables:

(defvar sigbegone-auto-rules-cache 'invalid)

(defvar sigbegone-rules-cache 'invalid)

(defvar sigbegone-rules-regexp-cache 'invalid)

(defvar sigbegone-exorcized-overlay-category nil
  "This is used for its symbol properties and symbol identity only.")

(defvar sigbegone-denounce-overlay-category nil
  "This is used for its symbol properties and symbol identity only.")

;; Functions:

(defun sigbegone-add-overlay (begin end category)
  (let ((overlay (make-overlay begin end)))
    (overlay-put overlay 'category category)))

(defun sigbegone-auto-rules ()
  (when (eq sigbegone-auto-rules-cache 'invalid)
    (sigbegone-invalidate-rules-caches)
    (setq sigbegone-auto-rules-cache
          (when sigbegone-exorcize-minusminusspace-sigs-p
            (list "-- \\(\n.*\\)+")))
    (mapcar (function
             (lambda (example)
               (let ((rule (sigbegone-example-matches-rule-list-p
                            example
                            sigbegone-manual-rules)))
                 (unless rule
                   ;; Didn't match a manual rule, so see if we already have
                   ;; an auto rule that matches.
                   (unless (sigbegone-example-matches-rule-list-p
                            example
                            sigbegone-auto-rules-cache)
                     ;; Didn't match an existing rule, so add a rule.
                     (setq sigbegone-auto-rules-cache
                           (cons (sigbegone-rule-for-example example)
                                 sigbegone-auto-rules-cache)))))))
            sigbegone-examples))
  sigbegone-auto-rules-cache)

(defun sigbegone-custom-set (&rest args)
  (sigbegone-invalidate-rules-caches)
  (apply 'set-default args))

(defun sigbegone-customize ()
  (interactive)
  (customize-group 'sigbegone))

(defun sigbegone-denounce-from-point (pt)
  (interactive "d")
  (save-match-data
    (let (begin end denounced-p)

      ;; Find the region of the sig.
      (save-excursion
        (beginning-of-line)
        (setq begin (point))
        (when (looking-at (concat "\\([ \t]*\n\\)+"))
          (goto-char (setq begin (match-end 0))))
        (unless (re-search-forward (concat sigbegone-whitespace-char-regexp
                                           "*\\'")
                                   nil t)
          (error "sigbegone internal error"))
        (setq end (match-beginning 0)))

      ;; Check that the region is non-null.
      (when (= begin end)
        (error "Move your point to the line that begins the offending sig."))

      ;; Check that the sig with can be matched with our current max search
      ;; distance setting.
      (let ((required-search-distance (- (point-max) begin)))
        (when (> required-search-distance sigbegone-exorcize-search-distance)
          (error
           "Increase `sigbegone-exorcize-search-distance' to at least %d."
           required-search-distance)))

      ;; Prompt the user for whether or not to denounce the sig.
      (unwind-protect
          (progn
            (sigbegone-delete-overlays)
            (sigbegone-add-overlay begin end
                                   'sigbegone-denounce-overlay-category)
            (let* ((win (selected-window))
                   (saved-win-start (window-start win)))
              (unwind-protect
                  (progn
                    (unless (pos-visible-in-window-p end win)
                      (set-window-start win begin))
                    (setq denounced-p
                          (y-or-n-p "Denounce the highlighted sig? ")))
                ;; unwind-protect cleanup
                (set-window-start win saved-win-start))))
        ;; unwind-protect cleanup
        (sigbegone-delete-overlays))

      ;; If user confirmed, then add the sig to the auto-rules and exorcize
      ;; this buffer with the new rules.
      (if denounced-p
          (progn
            (message "Denouncing...")
            (setq sigbegone-examples
                  (cons (buffer-substring-no-properties begin end)
                        sigbegone-examples))
            (sigbegone-invalidate-rules-caches)
            (sigbegone-save)
            (sigbegone-exorcize-buffer)
            (message "Denounced!"))
        (message "Reprieved!")))))
  
(defun sigbegone-delete-overlays ()
  (mapcar (function (lambda (list)
                      (while list
                        (when (memq (overlay-get (car list) 'category) 
                                    '(sigbegone-exorcized-overlay-category
                                      sigbegone-denounce-overlay-category))
                          (delete-overlay (car list)))
                        (setq list (cdr list)))))
          (let ((lists (overlay-lists)))
            (list (car lists)
                  (cdr lists)))))

(defun sigbegone-example-matches-rule-list-p (example rule-list)
  (unless (stringp example)
    (signal 'wrong-type-argument (list 'stringp example)))
  (save-match-data
    (let ((match nil))
      (while (and rule-list (not match))
        (let ((rule (car rule-list)))
          (if (let ((case-fold-search t))
                (string-match (concat "\\`" rule "\\'") example))
              (setq match rule)
            (setq rule-list (cdr rule-list)))))
      match)))

(defun sigbegone-exorcize-buffer ()
  (interactive)
  (save-excursion
    (save-match-data
      (sigbegone-delete-overlays)
      (let* ((rules-regexp (sigbegone-rules-regexp))
             (full-regexp  (when rules-regexp
                             (concat "^\\("
                                     rules-regexp
                                     "\\)"
                                     sigbegone-whitespace-char-regexp
                                     "*"
                                     "\\'"))))
        (when full-regexp
          (goto-char (max (- (point-max) sigbegone-exorcize-search-distance)
                          (point-min)))
          (when (let ((case-fold-search t))
                  (re-search-forward full-regexp nil t))
            (let ((match-begin (match-beginning 1))
                  (match-end   (match-end       1)))
              (when (= match-begin match-end)
                (error
                 "sigbegone rules are broken. match of length 0 at point %d."
                 match-begin))
              (sigbegone-add-overlay
               match-begin match-end
               'sigbegone-exorcized-overlay-category))))))))

(defun sigbegone-invalidate-rules-caches ()
  (setq sigbegone-auto-rules-cache   'invalid
        sigbegone-rules-cache        'invalid
        sigbegone-rules-regexp-cache 'invalid))
  
(defun sigbegone-modify-local-keymap ()
  (local-set-key "\C-c\C-s" 'sigbegone-denounce-from-point))
  
(defun sigbegone-put-alist (symbol alist)
  (mapcar (function (lambda (cell)
                      (put symbol (nth 0 cell) (cdr cell))))
          alist))

(defun sigbegone-rule-for-example (example)
  (regexp-quote (downcase example)))

(defun sigbegone-rules ()
  (let ((auto-rules (sigbegone-auto-rules)))
    (when (eq sigbegone-rules-cache 'invalid)
      (setq sigbegone-rules-cache
            (append sigbegone-manual-rules
                    auto-rules))
      (setq sigbegone-rules-regexp-cache 'invalid)))
  sigbegone-rules-cache)

(defun sigbegone-rules-regexp ()
  (let ((rules (sigbegone-rules)))
    (when (eq sigbegone-rules-regexp-cache 'invalid)
      (setq sigbegone-rules-regexp-cache
            (when rules
              (mapconcat (function (lambda (rule)
                                     (concat "\\(" rule "\\)")))
                         rules
                         "\\|")))))
  sigbegone-rules-regexp-cache)

(defun sigbegone-save ()
  (customize-save-variable 'sigbegone-examples sigbegone-examples))

;; Initialization:

(sigbegone-invalidate-rules-caches)

(sigbegone-put-alist 'sigbegone-exorcized-overlay-category
                     '((face       . sigbegone-exorcized-face)
                       (mouse-face . sigbegone-exorcized-mouse-face)
                       (priority   . 666)))
(sigbegone-put-alist 'sigbegone-denounce-overlay-category
                     '((face       . sigbegone-denounce-face)
                       (priority   . 667)))

(defadvice vm-energize-urls (after sigbegone-advice-vm activate)
  (sigbegone-exorcize-buffer))

(eval-after-load "vm"
  (when sigbegone-define-vm-keys-p
    (add-hook 'vm-visit-folder-hook 'sigbegone-modify-local-keymap)))

(eval-after-load "gnus-art"
  (progn
    (when sigbegone-define-gnus-keys-p
      (add-hook 'gnus-article-mode-hook 'sigbegone-modify-local-keymap))
    (add-hook 'gnus-article-prepare-hook 'sigbegone-exorcize-buffer)))

;; TODO:
;;
;; Author's To-Do List:
;;
;; * Automatically check rules for ones that will match empty string.
;;
;; * Make `sigbegone-exorcize-search-distance' ignore whitespace at and of
;;   buffer.
;;
;; * Update the `custom' form whenever `sigbegone-examples' changes.
;;
;; * Maybe build end-of-line whitespace handling into regexp in
;;   `sigbegone-rule-for-example'.
;;
;; * Maybe offer in `sigbegone-denounce-from-point' to increase value of
;;   `sigbegone-exorcize-search-distance' as needed.
;;
;; * Maybe have an option to store `sigbegone-examples' in a dotfile rather
;;   than in the `custom' database.
;;
;; * Maybe have a way of getting updated default `sigbegone-manual-rules' in
;;   later versions of packages without overwriting custom versions.  Probably
;;   defer this until/unless we ever code more sopisticated rules (which should
;;   be easy to make backward-compatible with string-based existing rule
;;   representation).
;;
;; * Maybe add commands to the VM menus.

(provide 'sigbegone)

;;; sigbegone.el ends here
