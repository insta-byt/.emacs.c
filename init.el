(defvar file-name-handler-alist-old file-name-handler-alist)

(setq ;package-enable-at-startup nil
      file-name-handler-alist nil
      message-log-max 16384
      gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6
      auto-window-vscroll nil)

(add-hook 'after-init-hook
          `(lambda ()
             (setq file-name-handler-alist file-name-handler-alist-old
                   gc-consq-threshold 1600000
                   gc-cons-percentage 0.1)
             (garbage-collect)) t)

;; In noninteractive sessions, prioritize non-byte-compiled source files to
;; prevent the use of stale byte-code. Otherwise, it saves us a little IO time
;; to skip the mtime checks on every *.elc file.
(setq load-prefer-newer noninteractive)

;; Report load time after initializing
(add-hook 'after-init-hook 'emacs-init-time)

(setq use-package-verbose t)

;; Put this file in register e for easy access
(set-register ?e `(file . ,user-init-file))

;;==================================================
;; Harden emacs TLS config based on
;; https://glyph.twistedmatrix.com/2015/11/editor-malware.html but
;; using a local cacert.pem instead of relying on certify.
;; https://raw.githubusercontent.com/certifi/python-certifi/master/certifi/cacert.pem
;; ==================================================

;;(unless (executable-find "gnutls-cli")
;;  (error "make sure gnutls-cli is in your $PATH"))

(let ((trustfile (expand-file-name "cacert.pem" user-emacs-directory)))
  (setq tls-program
        (list
         (format "gnutls-cli%s --x509cafile %s -p %%p %%h"
                 (if (eq window-system 'w32) ".exe" "") trustfile))
        tls-checktrust t
        gnutls-verify-error t
        gnutls-trustfiles (list trustfile)))

;;==================================================
;; Setup basic stuff
;;==================================================

(defconst *is-a-mac* (eq system-type 'darwin))
(defconst *is-a-windowed-mac* (and *is-a-mac* window-system))
(defvar jc-interactive-mode (not noninteractive)
  "If non-nil, Emacs is in interactive mode.")

;; Turn off mouse interface early in startup to avoid momentary display
(unless *is-a-windowed-mac* ; hide menu if not in Mac
  (if (fboundp 'menu-bar-mode) (menu-bar-mode -1)))
(if (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(if (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))

;; Less noise at startup. The dashboard/empty scratch buffer is good enough.
(setq inhibit-startup-message t
      inhibit-startup-echo-area-message user-login-name
      inhibit-default-init t
      initial-major-mode 'fundamental-mode
      initial-scratch-message nil)

;; Keep emacs custom-settings in separate file
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(load custom-file)

;;==================================================
;; Setup package management tools
;;==================================================

(unless (fboundp 'url-insert-buffer-contents)
  (require 'url-handlers))

(require 'package)
(setq package-enable-at-startup nil
      package-archives
      '(("gnu"   . "https://elpa.gnu.org/packages/")
		("melpa" . "https://melpa.org/packages/")))
(package-initialize)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(setq use-package-always-ensure t)
(require 'use-package)

(if init-file-debug
    (setq use-package-verbose t
          use-package-expand-minimally nil
          use-package-compute-statistics t
          debug-on-error t)
  (setq use-package-verbose nil
        use-package-expand-minimally t))

(use-package jc-doom
  :ensure nil
  :load-path "site-lisp")

(use-package gcmh
  :defer t
  :if jc-interactive-mode
  :commands gcmh-mode)

(when jc-interactive-mode
  (add-transient-hook! 'pre-command-hook (gcmh-mode +1))
  (with-eval-after-load 'gcmh
    (setq gcmh-idle-delay 10
          gcmh-high-cons-threshold 16777216
          gcmh-verbose nil
          gc-cons-percentage 0.1)
    (add-hook 'focus-out-hook #'gcmh-idle-garbage-collect)))


;;==================================================
;; Appearance settings
;;==================================================
;; (use-package zenburn-theme
;;   :config
;;   (load-theme 'zenburn t))
;; (use-package sunburn-theme
;;   :config
;;   (load-theme 'sunburn t))

;; (use-package spacemacs-theme
;;   :defer t
;;   :init
;;   (load-theme 'spacemacs-dark t))

(use-package all-the-icons
  :commands (all-the-icons-octicon
             all-the-icons-faicon
             all-the-icons-fileicon
             all-the-icons-wicon
             all-the-icons-material
             all-the-icons-alltheicon))

;; TODO: nodefer
(use-package doom-themes
  :config
  ;; Global settings (defaults)
  (setq doom-themeds-enable-bold nil    ; if nil, bold is universally disabled
        doom-themes-enable-italic nil
        doom-one-brighter-modeline nil)
  ;; (load-theme 'doom-opera t)
  ;; (load-theme 'doom-spacegrey t)
  ;; (load-theme 'doom-tomorrow-night t)
  ;; (load-theme 'doom-nord t)
  (load-theme 'doom-one t)
  ;; Enable flashing mode-line on errors
  (doom-themes-visual-bell-config))

(use-package doom-modeline
  :init
  (setq doom-modeline-bar-width 2
        doom-modeline-enable-word-count t)
  (unless after-init-time
    ;; prevent flash of unstyled modeline at startup
    (setq-default mode-line-format nil))
  :config
  (add-hook 'magit-mode-hook
    (lambda ()
      "Show minimal modeline in magit-status buffer, no modeline elsewhere."
      (if (eq major-mode 'magit-status-mode)
          (doom-modeline-set-vcs-modeline)
        (hide-mode-line-mode))))
  (doom-modeline-mode))

(use-package centaur-tabs
  ;;:after-call after-find-file dired-initial-position-hook
  :init
  (setq centaur-tabs-style "bar"
        centaur-tabs-height 32
        centaur-tabs-gray-out-icons 'buffer
        centaur-tabs-set-icons t
        centaur-tabs-set-bar 'under
        centaur-tabs-set-close-button t
        centaur-tabs-icon-scale-factor 0.7
        centaur-tabs-close-button "✕"
        centaur-tabs-show-navigation-buttons nil
        centaur-tabs-set-modified-marker nil
        centaur-tabs-modified-marker "⬤")
  :config
  (centaur-tabs-headline-match)
  (centaur-tabs-mode +1)
  (after! undo-tree (add-hook 'undo-tree-visualizer-mode-hook #'centaur-tabs-local-mode)))

(use-package winum
  :after-call after-init-hook
  :config
  (winum-mode +1))

;; TODO: nodefer
(use-package solaire-mode
  :hook
  ((change-major-mode after-revert ediff-prepare-buffer) . turn-on-solaire-mode)
  (minibuffer-setup . solaire-mode-in-minibuffer)
  :config
  (solaire-global-mode +1)
  (solaire-mode-swap-bg))

;; Resizing the Emacs frame can be a terribly expensive part of changing the
;; font. By inhibiting this, we halve startup times, particularly when we use
;; fonts that are larger than the system default (which would resize the frame).
(setq frame-inhibit-implied-resize t)
(setq default-frame-alist '((cursor-type . (bar . 2))))
(setq-default frame-background-mode 'dark)

; Don't defer screen updates when performing operations
(setq redisplay-dont-pause t)

(when window-system
  (setq frame-title-format '(buffer-file-name "%f" ("%b"))
        icon-title-format frame-title-format)
  (tooltip-mode nil)
  (blink-cursor-mode nil))

;; Set default font
;(if (find-font (font-spec :name "Fira Code"))
;;    (set-default-font "Fira Code 13")
; (message "Can't find font"))

;; Other good fonts. Test text: ()[]l1t  O0o Ilegal1 = O0
;; (set-face-font 'default "Envy Code R 13")
;; (set-face-font 'default "ProggyCleanTT Nerd Font Complete 12")
;; (set-face-font 'default "gohufont")
;; (set-face-font 'default "Consolas 14")
;; (set-face-font 'default "Source Code Pro 14")
;; (set-face-font 'default "Droid Sans Mono Dotted 10")
;; (set-face-font 'default "Anonymous Pro 14")
;; (set-face-font 'default "Liberation Mono 10")
;; (set-face-font 'default "Ubuntu Mono 11")
;; (set-face-font 'default "MonteCarlo")
;; (set-face-font 'default "Inconsolata 16")

;; Put fringe on the side
(if (fboundp 'fringe-mode) (fringe-mode))

(global-font-lock-mode +1)               ; just in case
(line-number-mode +1)
(column-number-mode +1)

;; Explicitly define a width to reduce computation
(setq-default display-line-numbers-width 3)

;; Show absolute line numbers for narrowed regions makes it easier to tell the
;; buffer is narrowed, and where you are, exactly.
(setq-default display-line-numbers-widen nil)
                                        ;(global-linum-mode 1)
(add-hook! '(prog-mode-hook text-mode-hook conf-mode-hook)
           #'display-line-numbers-mode)

;; More performant rapid scrolling over unfontified regions. May cause brief
;; spells of inaccurate syntax highlighting right after scrolling, which should
;; quickly self-correct.
(setq fast-but-imprecise-scrolling t)

(use-package highlight-numbers
  :commands highlight-numbers-mode
  :hook ((prog-mode conf-mode) . highlight-numbers-mode)
  :config (setq highlight-numbers-generic-regexp "\\_<[[:digit:]]+\\(?:\\.[0-9]*\\)?\\_>"))

;(setq scroll-conservatively 100000)
;(setq scroll-preserve-screen-position 'always)
;(setq scroll-step 0); what?

(setq hscroll-margin 2
      hscroll-step 1
      ;; Emacs spends too much effort recentering the screen if you scroll the
      ;; cursor more than N lines past window edges (where N is the settings of
      ;; `scroll-conservatively'). This is especially slow in larger files
      ;; during large-scale scrolling commands. If kept over 100, the window is
      ;; never automatically recentered.
      scroll-conservatively 101
      scroll-margin 0
      scroll-preserve-screen-position t
      ;; Reduce cursor lag by a tiny bit by not auto-adjusting `window-vscroll'
      ;; for tall lines.
      auto-window-vscroll nil
      ;; mouse
      mouse-wheel-scroll-amount '(5 ((shift) . 2))
      mouse-wheel-progressive-speed nil)  ; don't accelerate scrolling

;; Remove hscroll-margin in shells, otherwise it causes jumpiness
(setq-hook! '(eshell-mode-hook term-mode-hook) hscroll-margin 0)

(when *is-a-mac*
  ;; sane trackpad/mouse scroll settings
  (setq mac-redisplay-dont-reset-vscroll t
        mac-mouse-wheel-smooth-scroll nil))

;;==================================================
;; General settings
;;=================================================

(setq mouse-yank-at-point t                  ; mouse pastes at point
      x-select-enable-clipboard t            ; Allow pasting selection outside of Emacs
      global-auto-revert-non-file-buffers t  ; auto refresh dired
      auto-revert-verbose nil                ; and be quiet about it
      eval-expression-print-level nil
      echo-keystrokes 0.02                    ; Show keystrokes in progress
      confirm-kill-emacs 'yes-or-no-p        ; ask me before closing
      history-length 1000                    ; looong history
      use-dialog-box nil                     ; never show a dialog box
      use-file-dialog nil
      mark-even-if-inactive t                ;
      enable-recursive-minibuffers t         ; yes, please
      highlight-nonselected-windows t        ; show region even on inactive windows
      require-final-newline t                ; end files with a newline
      fill-column 80
      compilation-scroll-output t
      grep-highlight-matches t
      set-mark-command-repeat-p t
      isearch-allow-scroll t
      blink-matching-paren-distance 51200
      confirm-nonexistent-file-or-buffer nil
      indicate-buffer-boundaries nil
      indicate-empty-lines t
      x-underline-at-descent-line t
      next-line-add-newlines nil) ; don't add new lines when scrolling down

;; A second, case-insensitive pass over `auto-mode-alist' is time wasted, and
;; indicates misconfiguration (or that the user needs to stop relying on case
;; insensitivity).
(setq auto-mode-case-fold nil)

;; Disable warnings from legacy advice system. They aren't useful, and what can
;; we do about them, besides changing packages upstream?
(setq ad-redefinition-action 'accept)

;; Make apropos omnipotent. It's more useful this way.
(setq apropos-do-all t)


(setq-default visible-bell t)
;(setq-default show-trailing-whitespace t)
(setq-default highlight-tabs t)
(setq-default indicate-empty-lines t)
(setq-default word-wrap t)
(setq-default truncate-lines t)         ; don't word-wrap
(setq truncate-partial-width-windows nil)
(setq-default save-interprogram-paste-before-kill t)
(setq-default set-mark-command-repeat-pop t)
(setq shift-select-mode nil)            ; this is not windows
(setq delete-by-moving-to-trash t)
(setq sentence-end-double-space nil)

;; Disable bidirectional text rendering for a modest performance boost.
(setq-default bidi-display-reordering 'left-to-right
              bidi-paragraph-direction 'left-to-right)

;; confirm with y/n only
(defalias 'yes-or-no-p 'y-or-n-p)

(setq hippie-expand-try-functions-list '(try-expand-dabbrev
                                         try-expand-dabbrev-all-buffers
                                         try-expand-dabbrev-from-kill
                                         try-complete-file-name-partially
                                         try-complete-file-name
                                         try-expand-all-abbrevs
                                         try-expand-list
                                         try-expand-line
                                         try-complete-lisp-symbol-partially
                                         try-complete-lisp-symbol))
(bind-key "M-s-/" #'hippie-expand)

(use-package helpful
  :commands helpful--read-symbol
  :bind
  ([remap describe-function] . #'helpful-callable)
  ([remap describe-command]  . #'helpful-command)
  ([remap describe-variable] . #'helpful-variable)
  ([remap describe-key]      . #'helpful-key)
  ([remap describe-symbol]   . #'helpful-symbol)
  :init
  (after! apropos
    ;; patch apropos buttons to call helpful instead of help
    (dolist (fun-bt '(apropos-function apropos-macro apropos-command))
      (button-type-put
       fun-bt 'action
       (lambda (button)
         (helpful-callable (button-get button 'apropos-symbol)))))
    (dolist (var-bt '(apropos-variable apropos-user-option))
      (button-type-put
       var-bt 'action
       (lambda (button)
         (helpful-variable (button-get button 'apropos-symbol)))))))


;; Delete whitespace at the end of lines when saving
;; (add-hook 'before-save-hook 'delete-trailing-whitespace)

(use-package whitespace-cleanup-mode
  :commands whitespace-cleanup-mode
  :hook (prog-mode text-mode))

;; But don't show trailing whitespace in these modes
(defun sanityinc/no-trailing-whitespace ()
  "Turn off display of trailing whitespace in this buffer."
  (setq show-trailing-whitespace nil))

;; But don't show trailing whitespace in SQLi, inf-ruby etc.
(add-hook! '(special-mode-hook
             Info-mode-hook
             term-mode-hook
             ido-minibuffer-setup-hook
             comint-mode-hook
             compilation-mode-hook
             isearch-mode-hook
             minibuffer-setup-hook)
           #'sanityinc/no-trailing-whitespace)

;; don't confirm killing buffers with attached processes
(setq kill-buffer-query-functions
  (remq 'process-kill-buffer-query-function
         kill-buffer-query-functions))

;; Backup settings
(use-package files
  :ensure nil
  :init
  (setq backup-by-copying t            ; don't clobber symlinks
        delete-old-versions t          ; delete old backups
        kept-new-versions 6
        kept-old-versions 2
        version-control t         ; use versioned backups
        ;; Put autosave files (ie #foo#) and backup files (ie foo~) in ~/.emacs.d/.
        auto-save-file-name-transforms `((".*" ,(concat user-emacs-directory "backups/") t))
        backup-directory-alist `(("." . ,(concat user-emacs-directory "backups")))))


;; create the autosave dir if necessary, since emacs won't.
(make-directory "~/.emacs.d/autosaves/" t)

;; UTF-8 everything please
(when (fboundp 'set-charset-priority)
  (set-charset-priority 'unicode))
(setq locale-coding-system 'utf-8)
(set-terminal-coding-system 'utf-8)
(set-keyboard-coding-system 'utf-8)
(set-selection-coding-system 'utf-8)
(prefer-coding-system 'utf-8)
(set-language-environment 'utf-8)
(set-default-coding-systems 'utf-8)

;; Don't cripple my emacs
(setq disabled-command-function nil)

;; Useful modes
(auto-image-file-mode +1)                ; display images
(size-indication-mode +1)                ; display file size
(delete-selection-mode +1)               ; delete selected text on input
;(global-subword-mode 1)
(global-auto-revert-mode +1)             ; auto reload files if changed outside emacs
(auto-compression-mode +1)               ; open compressed files a la dired
(transient-mark-mode +1)                 ; show me the region, please
(winner-mode +1)                         ; stack window settings
(minibuffer-depth-indicate-mode +1)
(electric-indent-mode -1)             ; make return key not auto indent
;(desktop-save-mode 1)

;(fancy-narrow-mode)

;; don't let the cursor go into minibuffer prompt
(setq minibuffer-prompt-properties
      '(read-only t point-entered minibuffer-avoid-prompt face minibuffer-prompt))

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

;; (use-package highlight-parentheses
;;   :config
;;   (global-highlight-parentheses-mode t))

;; TODO: nodefer
(use-package volatile-highlights
  ;; :ensure hideshow
  ;; :after-call pre-command-hook
  :config
  (volatile-highlights-mode +1))

(use-package undo-tree
  :after-call pre-command-hook
  :config
  (setq undo-tree-auto-save-history t
        undo-limit 800000
        undo-strong-limit 12000000
        undo-outer-limit 120000000
        undo-tree-history-directory-alist `((".*" . ,(concat user-emacs-directory "undo-list"))))
  (global-undo-tree-mode))

;; Save a list of recent files visited.
(use-package recentf
  :after-call after-find-file
  :bind ("C-x f" . recentf-ido-find-file)
  :commands recentf-open-files
  :config
  (setq recentf-max-saved-items 500
        recentf-save-file (expand-file-name ".recentf" user-emacs-directory)
        recentf-auto-cleanup 'never
        recentf-max-menu-items 0
        recentf-exclude '("/tmp/" "/ssh:"))
  (add-hook! 'dired-mode-hook
             (defun doom--recentf-add-dired-directory-h ()
               "Add dired directory to recentf file list."
               (recentf-add-file default-directory)))

  (defun recentf-ido-find-file ()
    "Find a recent file using Ido."
    (interactive)
    (let ((file (ido-completing-read "Choose recent file: " recentf-list nil t)))
      (when file
        (find-file file))))
  (recentf-mode +1))

(setq history-length 1000)

(use-package savehist
  :after-call post-command-hook
  :config
  (setq savehist-file (expand-file-name ".savehist" user-emacs-directory)
        savehist-save-minibuffer-history t
        savehist-additional-variables '(kill-ring search-ring regexp-search-ring))
  (savehist-mode +1)
  (add-hook! 'kill-emacs-hook
    (defun doom-unpropertize-kill-ring-h ()
      "Remove text properties from `kill-ring' for a smaller savehist file."
      (setq kill-ring (cl-loop for item in kill-ring
                               if (stringp item)
                               collect (substring-no-properties item)
                               else if item collect it)))))

;; Never ever use tabs
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)            ;; but maintain correct apeparance

;; warn when opening files bigger than 100MB
(setq large-file-warning-threshold 100000000)

(add-hook 'after-save-hook 'executable-make-buffer-file-executable-if-script-p)

;; uniquify:  provide meaningful names for buffers with the same name
(use-package uniquify
  :ensure nil
  :init
  ;(setq uniquify-buffer-name-style 'forward)
  (setq uniquify-buffer-name-style 'forward)
  (setq uniquify-separator "/")
  (setq uniquify-after-kill-buffer-p t)     ; rename after killing uniquified
  (setq uniquify-ignore-buffers-re "^\\*")) ; don't muck with special buffers

;; use shift + arrow keys to switch between visible buffers
(use-package windmove
  :after-call window-configuration-change-hook
  :config
  (windmove-default-keybindings))

;; show-paren-mode: subtle highlighting of matching parens (global-mode)
(use-package paren
  :after-call pre-command-hook
  :config
  (setq show-paren-delay 0.1
        show-paren-style 'parenthesis
        show-paren-highlight-openparen t
        show-paren-when-point-inside-paren t
        show-paren-when-point-in-periphery t)
  (show-paren-mode +1))

;; Save point position between sessions
(use-package saveplace
  :after-call after-find-file dired-initial-position-hook
  :config
  (setq save-place-file (expand-file-name ".places" user-emacs-directory))
  (save-place-mode +1))

;; guide-key setup
;; (use-package guide-key
;;   :config
;;   (setq guide-key/guide-key-sequence '("C-x r" "C-x 4" "C-x v" "C-x 8"
;;                                        "C-x C-k" "<f8>" "C-c !" "M-s"
;;                                        "C-x n" "C-c p"))
;;   (add-hook 'dired-mode-hook
;;             (lambda () (guide-key/add-local-guide-key-sequence "%")))
;;   (guide-key-mode 1)
;;   (setq guide-key/recursive-key-sequence-flag t)
;;   (setq guide-key/popup-window-position 'bottom))

(use-package which-key
  :after-call pre-command-hook
  :init
  (setq which-key-sort-order #'which-key-prefix-then-key-order
        which-key-sort-uppercase-first nil
        which-key-add-column-padding 1
        which-key-max-display-columns nil
        which-key-min-display-lines 6
        which-key-side-window-slot -10)
  :config
  (which-key-setup-side-window-bottom)
  (setq which-key-max-description-length 45)
  (which-key-mode +1))

;; When popping the mark, continue popping until the cursor actually moves
;; Also, if the last command was a copy - skip past all the expand-region cruft.
(defadvice pop-to-mark-command (around ensure-new-position activate)
  (let ((p (point)))
    (when (eq last-command 'save-region-or-current-line)
      ad-do-it
      ad-do-it
      ad-do-it)
    (dotimes (i 10)
      (when (= p (point)) ad-do-it))))


;;==================================================
;; Mac-specific settings
;;==================================================
(when *is-a-mac*
  (setq delete-by-moving-to-trash t)
  ; left and right commands are meta
  (setq ns-command-modifier 'meta)
  (setq ns-right-command-modifier 'left)

  ; left opt key is super
  (setq ns-alternate-modifier 'super)
  ; right opt is ignored by emacs (useful for mac-style accent input)
  (setq ns-right-alternate-modifier 'none)

  ; left and right controls are control
  (setq ns-control-modifier 'control)
  (setq ns-right-control-modifier 'left)

  ; function key is hyper
  (setq ns-function-modifier 'hyper)

  (setq default-input-method "MacOSX")
  (setq insert-directory-program "gls")  ; dired works better with gls
  (setq default-directory (getenv "HOME"))
  (set-face-font 'default "Source Code Pro 14"))

(when *is-a-windowed-mac*
  (setq visible-bell nil) ;; The default
  (setq ns-use-native-fullscreen nil)
  (setq ns-use-fullscreen-animation nil)
  (setq ns-pop-up-frames nil)

  ;; set my path manually on mac
  (let* ((mypaths '("~/bin" "~/homebrew/bin"))
         (expanded (mapcar 'expand-file-name mypaths)))
    (setenv "PATH" (concat (string-join expanded ":") ":" (getenv "PATH")))
    (setq exec-path (append expanded exec-path))))

;; breaks doom theme
;; (setq ring-bell-function 'ignore)

(use-package ns-auto-titlebar
  :defer 1
  :if *is-a-windowed-mac*
  :config
  (ns-auto-titlebar-mode +1))

(use-package reveal-in-osx-finder
  :if *is-a-mac*
  :commands reveal-in-osx-finder)

; Stop C-z from minimizing windows under OS X
(when *is-a-windowed-mac*
  (unbind-key "C-z"))

;; enable electric pairs and indent
;; (when (fboundp 'electric-pair-mode)
;;   (electric-pair-mode))

;; (when (eval-when-compile (version< "24.4" emacs-version))
;;   (electric-indent-mode 1))

(bind-key "RET" #'newline-and-indent)

;;==================================================
;; ido settings
;;==================================================
(use-package ido
  :commands ido-mode)
(use-package flx
  :commands flx-ido-mode)
(use-package ido-grid-mode
  :commands ido-grid-mode)
(use-package ido-completing-read+
  :commands ido-ubiquitous-mode)

(use-package flx-ido
  :after-call after-init-hook
  :init
  (setq ido-enable-prefix nil
        ido-enable-flex-matching t
        ido-create-new-buffer 'always
        ido-use-filename-at-point nil
                                        ;ido-max-prospects 10
        ido-max-window-height 10
        ido-save-directory-list-file (expand-file-name ".ido.last" user-emacs-directory)
        ido-auto-merge-work-directories-length -1
        ido-default-file-method 'selected-window
        ido-ignore-extensions t
        ido-file-extensions-order '(".py" ".html" ".css" ".scss" "js"
                                    ".tf" ".md" ".rb" ".org" ".txt"
                                    ".c" ".cpp" ".cxx" ".h" ".hpp")
        ido-vertical-define-keys 'C-n-C-p-up-down-left-right)
  ;; (setq ido-vertical-define-keys 'C-n-C-p-up-down-left-right)
  (setq ido-use-faces nil)
  :config
  (ido-mode +1)
  (ido-everywhere +1)
  (flx-ido-mode +1)
  (ido-grid-mode +1)
  (ido-ubiquitous-mode +1))


;;==================================================
;; which-func-mode settings
;;==================================================
(which-function-mode +1)                 ; show me where I'm standing

; puts which-function-mode in the header
;; (setq-default header-line-format
;;               '((which-func-mode ("" which-func-format " "))))
;; (setq mode-line-misc-info
;;             ;; We remove Which Function Mode from the mode line, because it's mostly
;;             ;; invisible here anyway.
;;             (assq-delete-all 'which-func-mode mode-line-misc-info))

;;==================================================
;; git and magit settings
;;==================================================

;; TODO: load as needed
(use-package gitconfig-mode
  :mode (("\\.gitconfig\\'" . gitconfig-mode)
	     ("\\.git/config\\'" . gitconfig-mode)
	     ("\\.gitmodules\\'" . gitconfig-mode)))

(use-package gitignore-mode
  :mode ("\\.gitignore\\'" . gitignore-mode))

(use-package gl-conf-mode
  :load-path "site-lisp/gl-conf-mode"
  :mode "gitolite\\.conf\\'")

(use-package magit
  :bind
  (("C-x C-z" . magit-status)
   :map magit-status-mode-map
   ("q" . magit-quit-session))
  :config
  (setq magit-revision-show-gravatars '("^Author:     " . "^Commit:     ")
        magit-no-confirm '(stage-all-changes unstage-all-changes)
        magit-delete-by-moving-to-trash t
        magit-diff-refine-hunk 'all
        magit-save-repository-buffers nil)

  (defadvice magit-status (around magit-fullscreen activate)
    (window-configuration-to-register :magit-fullscreen)
    ad-do-it
    (delete-other-windows))

  (defun magit-quit-session ()
    "Restores the previous window configuration and kills the magit buffer"
    (interactive)
    (kill-buffer)
    (jump-to-register :magit-fullscreen)))


;; TODO: nodefer
(use-package git-commit
  :config
  (global-git-commit-mode +1)
  ;; Enforce git commit conventions.
  ;; See https://chris.beams.io/posts/git-commit/
  (setq git-commit-summary-max-length 50
        git-commit-style-convention-checks '(overlong-summary-line non-empty-second-line))

  (setq-hook! 'git-commit-mode-hook fill-column 72))

;;==================================================
;; isearch settings
;;==================================================

;; use regexp isearch by default
(bind-key [remap isearch-forward] #'isearch-forward-regexp)
(bind-key [remap isearch-backward] #'isearch-backward-regexp)

(define-key isearch-mode-map (kbd "C-o") 'isearch-occur)

(use-package jc-search
  :ensure nil
  :commands (zap-to-isearch isearch-exit-other-end isearch-yank-symbol)
  :init (bind-keys :map isearch-mode-map
                   ("M-z" . zap-to-isearch)
                   ("C-w" . isearch-yank-symbol)
                   ("C-RET" . isearch-exit-other-end)))

(define-key isearch-mode-map [(meta z)] 'zap-to-isearch)
(define-key isearch-mode-map [(control return)] 'isearch-exit-other-end)

;; DEL during isearch should edit the search string, not jump back to the previous result
(define-key isearch-mode-map [remap isearch-delete-char] 'isearch-del-char)

(use-package anzu
  :bind
  (([remap query-replace-regexp] . anzu-query-replace)
   ([remap query-replace] . anzu-query-replace-regexp)
   :map isearch-mode-map
   ([remap isearch-query-replace-regexp] . anzu-isearch-query-replace-regexp)
   ([remap isearch-query-replace] . anzu-isearch-query-replace-regexp))
  :config
  ;; show number of matches while searching
  (global-anzu-mode +1))

;;==================================================
;; elisp
;;==================================================
(use-package highlight-quoted
  :hook (emacs-lisp-mode . highlight-quoted-mode))

;(add-hook 'emacs-lisp-mode-hook 'hl-sexp-mode)

;;==================================================
;; smart-mode-line
;;==================================================
;; (use-package smart-mode-line
;;   :config
;;   (sml/setup))

;;==================================================
;; smartparens
;;==================================================
;;; req-todo
;; (use-package smartparens-config
;;   :ensure smartparens
;;   :bind (:map smartparens-mode-map
;;               ("C-M-a" . sp-beginning-of-sexp)
;;               ("C-M-e" . sp-end-of-sexp)

;;               ("C-<down>" . sp-down-sexp)
;;               ("C-<up>"   . sp-up-sexp)
;;               ("M-<down>" . sp-backward-down-sexp)
;;               ("M-<up>"   . sp-backward-up-sexp)

;;               ("C-M-f" . sp-forward-sexp)
;;               ("C-M-b" . sp-backward-sexp)

;;               ("C-M-n" . sp-next-sexp)
;;               ("C-M-p" . sp-previous-sexp)

;;               ("C-S-f" . sp-forward-symbol)
;;               ("C-S-b" . sp-backward-symbol)

;;               ("C-<right>" . sp-forward-slurp-sexp)
;;               ("M-<right>" . sp-backward-barf-sexp)
;;               ("C-<left>"  . sp-forward-barf-sexp)
;;               ("M-<left>"  . sp-backward-slurp-sexp)

;;               ("C-M-t" . sp-transpose-sexp)
;;               ("C-M-k" . sp-kill-sexpa)
;;               ("C-k"   . sp-kill-hybrid-sexp)
;;               ("M-k"   . sp-backward-kill-sexp)
;;               ("C-M-w" . sp-copy-sexp)

;;               ("C-M-d" . delete-sexp)

;;               ("M-<backspace>" . backward-kill-word)
;;               ("C-<backspace>" . sp-backward-kill-word)
;;               ([remap sp-backward-kill-word] . backward-kill-word)

;;               ;; breaks bracketed paste mode
;;               ;("M-[" . sp-backward-unwrap-sexp)
;;               ;("M-]" . sp-unwrap-sexp)

;;               ("C-x C-t" . sp-transpose-hybrid-sexp))
;;   :init
;;   (show-smartparens-global-mode)
;;   (smartparens-global-mode t))

;;==================================================
;; ediff
;;==================================================

(after! ediff
  (setq ediff-diff-options "-w" ; turn off whitespace checking
        ediff-split-window-function #'split-window-horizontally
        ediff-window-setup-function #'ediff-setup-windows-plain))

;;==================================================
;; scss-mode settings
;;==================================================
;; (use-package scss-mode
;;   :config
;;   (setq scss-compile-at-save nil))

;;==================================================
;; Dired settings
;;==================================================

(require 'dired)

; dired
;(setq dired-listing-switches "--time-style long-iso --group-directories-first -alhF")
(setq dired-listing-switches "--time-style long-iso -alhF")
(setq-default diredp-hide-details-initially-flag nil
              dired-dwim-target t) ; Move files between split pane

;; TODO: Move to autoload
;; M-up is nicer in dired if it moves to the fourth line - the first file
(defun dired-back-to-top ()
  (interactive)
  (beginning-of-buffer)
  (dired-next-line 4))

(define-key dired-mode-map (vector 'remap 'beginning-of-buffer) 'dired-back-to-top)
(define-key dired-mode-map (vector 'remap 'smart-up) 'dired-back-to-top)

(bind-key "C-x C-j" #'dired-jump)
(bind-key "C-x M-j" '(lambda () (interactive) (dired-jump 1)))

;; req-todo
;; (use-package dired+
;;   :config
;;   (global-dired-hide-details-mode -1))

(use-package peep-dired
  :bind (:map dired-mode-map
              ("P" . peep-dired)))

(defun make-parent-directory ()
  "Make sure the directory of `buffer-file-name' exists."
  (make-directory (file-name-directory buffer-file-name) t))

(add-hook 'find-file-not-found-functions #'make-parent-directory)

;;==================================================
;; browse-kill-ring settings
;;==================================================
;; TODO: nodefer
(use-package browse-kill-ring
  ;:after-call after-init-hook
  :config
  (browse-kill-ring-default-keybindings)
  (setq browse-kill-ring-highlight-current-entry t)
  (setq browse-kill-ring-highlight-inserted-item t)
  (setq browse-kill-ring-quit-action 'save-and-restore))

(use-package markdown-mode
  :mode (("README\\.md\\'" . gfm-mode)
         ("\\.md\\'" . markdown-mode)
         ("\\.markdown\\'" . markdown-mode)))


;;==================================================
;; multiple cursors
;;==================================================

(use-package multiple-cursors
  :bind (("C-S-<mouse-1>" . mc/add-cursor-on-click)
         ("C->" . mc/mark-next-like-this)
         ("C-<" . mc/mark-previous-like-this)
         ("C-c C-<" . mc/mark-all-like-this)
         ("C-c c r" . set-rectangular-region-anchor)
         ("C-c c t" . mc/mark-sgml-tag-pair)
         ("C-c c c" . mc/edit-lines)
         ("C-c c e" . mc/edit-ends-of-lines)
         ("C-c c a" . mc/edit-beginnings-of-lines)))

;;==================================================
;; paredit
;;==================================================
;; (use-package paredit
;;   :init
;;   (add-hook 'emacs-lisp-mode-hook 'enable-paredit-mode))

;;==================================================
;; change-inner/outer
;;==================================================

(use-package change-inner
  :bind (("M-I" . change-inner)
         ("M-O" . change-outer)))

;;==================================================
;; misc
;;==================================================
(use-package misc
  :ensure nil
  :bind ("M-z" . zap-up-to-char)
  :init (bind-key "\M-Z" #'zap-to-char))

(use-package jc-misc
  :ensure nil
  :commands (chmod+x-this)
  :bind ("M-p" . goto-match-paren))

(use-package crux
  :bind (("C-a" . crux-move-beginning-of-line)
         ("S-<return>" . crux-smart-open-line)
         ("C-S-k" . crux-kill-whole-line)
         ("C-S-<return>" . crux-smart-open-line-above))
  :config
  (crux-with-region-or-buffer indent-region)
  (crux-with-region-or-buffer untabify)
  (crux-reopen-as-root-mode +1))

;; (defadvice ido-find-file (after find-file-sudo activate)
;;   "Find file as root if necessary."
;;   (unless (and buffer-file-name
;;                (file-writable-p buffer-file-name))
;;     (find-alternate-file (concat "/sudo:root@localhost:" buffer-file-name))))

(use-package jc-windows
  :ensure nil
  :load-path "site-lisp"
  :bind (("C-x |" . split-window-horizontally-instead)
         ("C-x _" . split-window-vertically-instead)
         ("C-2" . split-window-vertically-with-other-buffer)
         ("C-3" . split-window-horizontally-with-other-buffer)
         ("C-s-j" . quick-switch-buffer)))

(bind-key "C-1" #'delete-other-windows)
(bind-key "C-0" #'delete-window)

(use-package bm
  :ensure nil
  :bind (("<C-f2>" . bm-toggle)
         ("<f2>" . bm-next)
         ("<S-f2>" . bm-previous)))

;; resize windows
(bind-key "S-C-<left>" #'shrink-window-horizontally)
(bind-key "S-C-<right>" #'enlarge-window-horizontally)
(bind-key "S-C-<down>" #'shrink-window)
(bind-key "S-C-<up>" #'enlarge-window)

; ibuffer
(use-package ibuffer
  :bind ("C-x C-b" . ibuffer))

; shrink-whitespace
(use-package shrink-whitespace
  :commands shrink-whitespace
  :bind ("M-SPC" . shrink-whitespace))

; beacon
(use-package beacon
  :defer 2
  :config
  (setq beacon-color "#6F6F6F"
        beacon-blink-when-focused  t)
  (beacon-mode))

;; move-text
(use-package drag-stuff
  :hook
  ((prog-mode text-mode conf-mode) . turn-on-drag-stuff-mode)
  :config
  (setq drag-stuff-modifier '(meta super))
  (drag-stuff-define-keys))

;; (defun sanityinc/newline-at-end-of-line ()
;;   "Move to end of line, enter a newline, and reindent."
;;   (interactive)
;;   (move-end-of-line 1)
;;   (newline-and-indent))

;; (bind-key "S-<return>" 'sanityinc/newline-at-end-of-line)

;; Cut/copy the current line if no region is active
(use-package whole-line-or-region
  :hook
  ((prog-mode text-mode conf-mode) . whole-line-or-region-local-mode)
  :config
  (whole-line-or-region-global-mode +1))

;;==================================================
;; ispell
;;==================================================
(setq ispell-program-name "aspell" ; use aspell instead of ispell
      ispell-extra-args '("--sug-mode=ultra"))

(let ((langs '("american" "castellano8")))
  (setq lang-ring (make-ring (length langs)))
  (dolist (elem langs) (ring-insert lang-ring elem)))

;; Todo: Move to autoload
(defun cycle-ispell-languages ()
  (interactive)
  (let ((lang (ring-ref lang-ring -1)))
    (ring-insert lang-ring lang)
    (ispell-change-dictionary lang)
    (flyspell-buffer)
    (message "Spell language changed to %s" lang)))

;; TODO: Move to autoload
(defun flyspell-check-next-highlighted-word ()
  "Custom function to spell check next highlighted word"
  (interactive)
  (flyspell-goto-next-error)
  (ispell-word))

(bind-keys :prefix-map jc-spelling-map
           :prefix "<f8>"
           ("<f8>" . ispell-word)
           ("m" . flyspell-mode)
           ("b" . flyspell-buffer)
           ("p" . flyspell-check-previous-highlighted-word)
           ("n" . flyspell-check-next-highlighted-word)
           ("c" . cycle-ispell-languages))

;;==================================================
;; mark customizations
;;==================================================
(use-package jc-marks
  :ensure nil
  :commands exchange-point-and-mark-no-activate
  :bind (("C-`" . push-mark-no-activate)
         ("M-`" . jump-to-mark)))

;;==================================================
;; swier settings
;;==================================================

;; (use-package ivy
;;   :require counsel
;;   :init
;;   (ivy-mode 1)
;;   (setq ivy-use-virtual-buffers t)
;;   (global-set-key "\C-s" 'swiper)
;;   (global-set-key (kbd "C-c C-r") 'ivy-resume)
;;   (global-set-key (kbd "<f6>") 'ivy-resume)
;;   (global-set-key (kbd "M-x") 'counsel-M-x)
;;   (global-set-key (kbd "C-x C-f") 'counsel-find-file)
;;   (global-set-key (kbd "<f1> f") 'counsel-describe-function)
;;   (global-set-key (kbd "<f1> v") 'counsel-describe-variable)
;;   (global-set-key (kbd "<f1> l") 'counsel-load-library)
;;   (global-set-key (kbd "<f2> i") 'counsel-info-lookup-symbol)
;;   (global-set-key (kbd "<f2> u") 'counsel-unicode-char)
;;   (global-set-key (kbd "C-c g") 'counsel-git)
;;   (global-set-key (kbd "C-c j") 'counsel-git-grep)
;;   (global-set-key (kbd "C-c k") 'counsel-ag)
;;   (global-set-key (kbd "C-x l") 'counsel-locate)
;;   (global-set-key (kbd "C-S-o") 'counsel-rhythmbox)
;;   (define-key read-expression-map (kbd "C-r") 'counsel-expression-history))

;;==================================================
;; smex settings
;;==================================================

;; (use-package smex
;;   :require ido
;;   :bind (("M-x" . smex)
;;          ("M-X" . smex-major-mode-commands)
;;          ("C-c C-c M-x" . execute-extended-command))
;;   :config
;;   (setq smex-save-file (expand-file-name "smex.items" user-emacs-directory))
;;   (smex-initialize))

(use-package amx
  ;:after-call after-init-hook
  :config
  (amx-mode +1))

;;==================================================
;; Projectile settings
;;==================================================

(use-package projectile
  :bind-keymap
  ("C-c p" . projectile-command-map)
  :config
  (setq projectile-mode-line
        '(:eval
          (format " Prj:%s"
                  (projectile-project-name))))

  (setq projectile-indexing-method 'alien)
  (setq projectile-enable-caching t)
  (setq projectile-sort-order 'recently-active)
  (when (executable-find "fd")
    (let ((fd-command "fd . --type f --print0"))
      (setq projectile-hg-command fd-command)
      (setq projectile-git-command fd-command)
      (setq projectile-fossil-command fd-command)
      (setq projectile-bzr-command fd-command)
      (setq projectile-darcs-command fd-command)
      (setq projectile-svn-command fd-command)
      (setq projectile-generic-command fd-command)))
  (projectile-mode +1)
  (setq projectile-require-project-file nil))

(use-package dumb-jump
  :bind (("M-g o" . dumb-jump-go-other-window)
         ("M-g j" . dumb-jump-go)
         ("M-g b" . dumb-jump-back)
         ("M-g i" . dumb-jump-go-prompt)
         ("M-g x" . dumb-jump-go-prefer-external)
         ("M-g z" . dumb-jump-go-prefer-external-other-window))
  ;:config (setq dumb-jump-selector 'ivy) ;; (setq dumb-jump-selector 'helm)
  )
;;==================================================
;; popup-imenu settings
;;==================================================

(use-package popup-imenu
  :bind ("M-i" . popup-imenu))

;;==================================================
;; company-mode settings
;;==================================================
(use-package company
  :defer 5
  :init
  (setq
   company-idle-delay 0.5
   company-show-numbers t
   company-dabbrev-downcase nil)
  :config
  (global-company-mode))

(use-package company-terraform
  :after terraform-mode
  :config
  (add-to-list 'company-backends 'company-terraform))

;; (use-package company-quickhelp          ; Documentation popups for Company
;;   :init (add-hook 'global-company-mode-hook #'company-quickhelp-mode))

(use-package yasnippet
  :defer-incrementally eldoc easymenu help-mode
  :commands yas-hippie-try-expand
  :init (progn
          (add-to-list 'hippie-expand-try-functions-list 'yas-hippie-try-expand)
          (yas-global-mode +1)))

(use-package yasnippet-snippets         ; Collection of snippets
  :after yasnippet)

(use-package flycheck
  :after-call after-find-file
  :config
  (setq flycheck-check-syntax-automatically '(save mode-enabled))
  (setq flycheck-display-errors-delay 0.25)
  (global-flycheck-mode))

(use-package flymake-shellcheck
  :after flycheck
  :commands flymake-shellcheck-load
  :hook (sh-mode . flymake-shellcheck-load))

;; (use-package flycheck-popup-tip
;;   :after flycheck
;;   :config
;;   (add-hook 'flycheck-mode-hook 'flycheck-popup-tip-mode))


(use-package flycheck-posframe
  :after flycheck
  :hook
  (flycheck-mode . flycheck-posframe-mode)
  :config
  (setq flycheck-posframe-border-width 2
        flycheck-posframe-warning-prefix "⚠ "
        flycheck-posframe-info-prefix "··· "
        flycheck-posframe-error-prefix "✕ ")
  (after! company
    ;; Don't display popups if company is open
    (add-hook 'flycheck-posframe-inhibit-functions #'company--active-p)))


  ;; (add-hook 'flycheck-mode-hook #'flycheck-posframe-mode)
  ;; (flycheck-posframe-configure-pretty-defaults)
  ;; (setq flycheck-posframe-border-width 2)
  ;; (set-face-foreground 'flycheck-posframe-border-face "red"))

;;==================================================
;; auto-complete settings
;;==================================================
;; (use-package fuzzy)
;; (use-package auto-complete
;;   :bind ("M-/" . auto-complete)
;;   :config
;;   (ac-config-default)
;;   (setq ac-auto-show-menu nil)
;;   (setq ac-auto-start nil)
;;   (setq ac-menu-height 15)
;;   (setq ac-fuzzy-enable t)
;;   (setq ac-dwim-enable t)
;;   (setq ac-use-menu-map t)
;;   (setq-default ac-sources '(ac-source-abbrev
;;                              ac-source-words-in-same-mode-buffers
;;                              ac-source-files-in-current-dir
;;                              ac-source-filename
;;                              ac-source-dictionary)))

;;==================================================
;; wgrep
;;==================================================

; ;; TODO: nodefer

(use-package wgrep)
(use-package ag)
(use-package wgrep-ag
  :if (executable-find "ag")
  :config
  (setq-default ag-highlight-search t))

;;==================================================
;; dockerfile settings
;;==================================================

(use-package dockerfile-mode)

;;==================================================
;; terraform settings
;;==================================================

(use-package terraform-mode
  :hook
  (terraform-mode . terraform-format-on-save-mode))

;;==================================================
;; web
;;==================================================
(use-package rust-mode
  :mode "\\.rs\\'")

;;==================================================
;; web
;;==================================================
(use-package web-mode
  :mode "\\.html?\\'"
  :config
  (setq web-mode-code-indent-offset 2)
  (setq web-mode-markup-indent-offset 2))

;; (setq web-mode-engines-alist
;;       '(("php" . "\\.phtml\\'")
;;         ("django" . "\\.html\\'")))


(setq js-indent-level 2)

(use-package yaml-mode
  :mode "\\.yaml?\\'")

(use-package json-mode
  :mode "\\.json?\\'")

(use-package scss-mode
  :mode "\\.scss?\\'"
  :init
  (setq scss-compile-at-save nil))

(use-package js2-mode
    :mode "\\.js\\'")

;;==================================================
;; jump-char
;;==================================================

;; NOTE: keep this after loading ido, otherwise M-m won't work inside
;; ido
;; (use-package jump-char
;;   :config
;;   :bind (("M-m" . jump-char-forward)
;;          ("M-M" . jump-char-backward)))

;;==================================================
;; python
;;==================================================

(use-package pip-requirements
  :mode "requirements\\.txt\\'")

;;==================================================
;; Misc packages and utilities
;;==================================================
;; (use-package paradox)
;; (use-package cypher-mode)
;; (use-package jade-mode)
(use-package highlight-symbol
  :commands (qhighlight-symbol
             highlight-symbol-query-replace
             highlight-symbol-occur))
;; (use-package ssh-config-mode)

(use-package avy
  :bind (("M-g g" . avy-goto-line)
         ;("C-'" . avy-goto-char)
         ("C-\"" . avy-goto-char-timer))
  :config
  (setq avy-keys
        '(?c ?a ?s ?d ?e ?f ?h ?w ?y ?j ?k ?l ?n ?m ?v ?r ?u ?p))
  (avy-setup-default))

(use-package ace-window
  :bind
  ([remap other-window] . ace-window)
  :config
  (setq aw-keys '(?a ?s ?d ?f ?g ?h ?j ?k ?l))
  (setq aw-dispatch-always nil))

(use-package expand-region
  :bind ("C-=" . er/expand-region))

(use-package rainbow-mode
  :commands rainbow-mode
  :hook (css-mode html-mode))

;; ;; keep scratch around
;; (save-excursion
;;   (set-buffer (get-buffer-create "*scratch*"))
;;   (lisp-interaction-mode)
;;   (make-local-variable 'kill-buffer-query-functions)
;;   (add-hook 'kill-buffer-query-functions 'kill-scratch-buffer))

;; (defun kill-scratch-buffer ()
;;   ;; The next line is just in case someone calls this manually
;;   (set-buffer (get-buffer-create "*scratch*"))
;;   ;; Kill the current (*scratch*) buffer
;;   (remove-hook 'kill-buffer-query-functions 'kill-scratch-buffer)
;;   (kill-buffer (current-buffer))
;;   ;; Make a brand new *scratch* buffer
;;   (set-buffer (get-buffer-create "*scratch*"))
;;   (lisp-interaction-mode)
;;   (make-local-variable 'kill-buffer-query-functions)
;;   (add-hook 'kill-buffer-query-functions 'kill-scratch-buffer)
;;   (insert initial-scratch-message)
;;   ;; Since we killed it, don't let caller do that.
;;   nil)


(defadvice comment-dwim (around comment-line-maybe activate)
  "If invoked from the beginning of a line or the beginning of
text on a line, comment the current line instead of appending a
comment to the line."
  (if (and (not (use-region-p))
           (not (eq (line-end-position)
                    (save-excursion (back-to-indentation) (point))))
           (or (eq (point) (line-beginning-position))
               (eq (point) (save-excursion (back-to-indentation) (point)))))
      (comment-or-uncomment-region (line-beginning-position)
                                   (line-end-position))
    ad-do-it
    (setq deactivate-mark nil)))


;;==================================================
;; require additional local settings (if they exist)
;;==================================================

(setq jc-local-settings
      (expand-file-name "jc-local.el" user-emacs-directory))

(if (file-exists-p jc-local-settings)
    (load-file jc-local-settings))

;;==================================================
;; experiments
;;==================================================
;; (use-package golden-ratio
;;   :diminish golden-ratio-mode
;;   :init (golden-ratio-mode 1))

;; (use-package guru-mode
;;   :config (guru-global-mode 1)
;;   :diminish guru-mode)


;;==================================================
;; server
;;==================================================

(use-package server
  :if window-system
  :init
  (add-hook 'after-init-hook 'server-start t))


;; `keyboard-quit' is too much of a nuclear option. I wanted an ESC/C-g to
;; do-what-I-mean. It serves four purposes (in order):
;;
;; 1. Quit active states; e.g. highlights, searches, snippets, iedit,
;;    multiple-cursors, recording macros, etc.
;; 2. Close popup windows remotely (if it is allowed to)
;; 3. Refresh buffer indicators, like git-gutter and flycheck
;; 4. Or fall back to `keyboard-quit'
;;
;; And it should do these things incrementally, rather than all at once. And it
;; shouldn't interfere with recording macros or the minibuffer. This may require
;; you press ESC/C-g two or three times on some occasions to reach
;; `keyboard-quit', but this is much more intuitive.

(defvar doom-escape-hook nil
  "A hook run when C-g is pressed (or ESC in normal mode, for evil users).
More specifically, when `doom/escape' is pressed. If any hook returns non-nil,
all hooks after it are ignored.")

(defun doom/escape ()
  "Run `doom-escape-hook'."
  (interactive)
  (cond ((minibuffer-window-active-p (minibuffer-window))
         ;; quit the minibuffer if open.
         (abort-recursive-edit))
        ;; Run all escape hooks. If any returns non-nil, then stop there.
        ((run-hook-with-args-until-success 'doom-escape-hook))
        ;; don't abort macros
        ((or defining-kbd-macro executing-kbd-macro) nil)
        ;; Back to the default
        ((keyboard-quit))))

(bind-key [remap keyboard-quit] #'doom/escape)

;; Don't resize windows & frames in steps; it's prohibitive to prevent the user
;; from resizing it to exact dimensions, and looks weird.
(setq window-resize-pixelwise t
      frame-resize-pixelwise t)


;; The native border "consumes" a pixel of the fringe on righter-most splits,
;; `window-divider' does not. Available since Emacs 25.1.
(setq window-divider-default-places t
      window-divider-default-bottom-width 1
      window-divider-default-right-width 1)
(window-divider-mode t)

 ;; Favor vertical splits over horizontal ones. Screens are usually wide.
(setq split-width-threshold 160
      split-height-threshold nil)

(setq resize-mini-windows 'grow-only
      ;; But don't let the minibuffer grow beyond this size
      max-mini-window-height 0.15)

;; Enable mouse in terminal Emacs
(add-hook 'tty-setup-hook #'xterm-mouse-mode)

(use-package hl-line
  ;; Highlights the current line
  :hook ((prog-mode text-mode conf-mode) . hl-line-mode)
  :config
  ;; Not having to render the hl-line overlay in multiple buffers offers a tiny
  ;; performance boost. I also don't need to see it in other buffers.
  (setq hl-line-sticky-flag nil
        global-hl-line-sticky-flag nil)

  ;; Temporarily disable `hl-line' when selection is active, since it doesn't
  ;; serve much purpose when the selection is so much more visible.
  (defvar doom--hl-line-mode nil)

  (add-hook 'activate-mark-hook
    (defun doom-disable-hl-line-h ()
      (when hl-line-mode
        (setq-local doom--hl-line-mode t)
        (hl-line-mode -1))))

  (add-hook 'deactivate-mark-hook
    (defun doom-enable-hl-line-maybe-h ()
      (when doom--hl-line-mode
        (hl-line-mode +1)))))


(setq image-animate-loop t)

;; Resolve symlinks when opening files, so that any operations are conducted
;; from the file's true directory (like `find-file').
(setq find-file-visit-truename t
      vc-follow-symlinks t)

;; Disable the warning "X and Y are the same file". It's fine to ignore this
;; warning as it will redirect you to the existing buffer anyway.
(setq find-file-suppress-same-file-warnings t)

;; Allow UTF or composed text from the clipboard, even in the terminal or on
;; non-X systems (like Windows or macOS), where only `STRING' is used.
(setq x-select-request-type '(UTF8_STRING COMPOUND_TEXT TEXT STRING))


(use-package restart-emacs
  :commands restart-emacs)

(use-package hl-todo
  :hook (prog-mode . hl-todo-mode)
  :config
  (setq hl-todo-highlight-punctuation ":"
        hl-todo-keyword-faces
        `(;; For things that need to be done, just not today.
          ("TODO" warning bold)
          ;; For problems that will become bigger problems later if not
          ;; fixed ASAP.
          ("FIXME" error bold)
          ;; For tidbits that are unconventional and not intended uses of the
          ;; constituent parts, and may break in a future update.
          ("HACK" font-lock-constant-face bold)
          ;; For things that were done hastily and/or hasn't been thoroughly
          ;; tested. It may not even be necessary!
          ("REVIEW" font-lock-keyword-face bold)
          ;; For especially important gotchas with a given implementation,
          ;; directed at another user other than the author.
          ("NOTE" success bold)
          ;; For things that just gotta go and will soon be gone.
          ("DEPRECATED" font-lock-doc-face bold))))

(use-package highlight-indent-guides
  :hook ((prog-mode text-mode conf-mode) . highlight-indent-guides-mode)
  :init
  (setq highlight-indent-guides-method 'character))

(after! compile
  (setq compilation-always-kill t       ; kill compilation process before starting another
        compilation-ask-about-save nil  ; save all buffers on `compile'
        compilation-scroll-output 'first-error)
  ;; Handle ansi codes in compilation buffer
  (add-hook 'compilation-filter-hook #'doom-apply-ansi-color-to-compilation-buffer-h))


(add-hook! '(completion-list-mode-hook Man-mode-hook)
           #'hide-mode-line-mode)

;; TODO doom: recentf better-jumber dtrt-indent smartparens so-long
;; ws-butler pcre2el highlight-doom/escape auto-revert
;; company ivy workspaces lsp visual-line-mode
;;
;; zstd (un)compress
;;
;; use-package defer

(use-package-report)
