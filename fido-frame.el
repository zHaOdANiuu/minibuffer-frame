;;; fido-frame.el --- Fido minibuffer in centered child frame -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Daniu Zhao

;; Author: Daniu Zhao <zhaodaniu1@gmail.com>
;; Homepage: https://github.com/zHaOdANiuu/fido-frame
;; Version: 0.0.1
;; Package-Requires: ((emacs "28.1"))
;; Keywords: convenience, fido, child-frame

;; This file is not part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Display fido completions in a floating child frame
;; centered on the parent frame, instead of the default minibuffer
;; area at the bottom of the window.
;;
;; Usage:
;;   (require 'fido-frame)
;;   (fido-frame-mode 1)

;;; Code:

(require 'cl-lib)

(defvar fido-frame--frame nil
  "The child frame used as a dedicated minibuffer window.")

(defvar fido-frame-saved-minibuffer-follow t
  "Saved value of `minibuffer-follows-selected-frame' to restore on exit.")

(defgroup fido-frame nil
  "Display fido completions in a centered child frame."
  :group 'convenience
  :prefix "fido-frame-")

(defcustom fido-frame-width 0.5
  "Child frame width as a fraction of the parent frame."
  :type 'number :group 'fido-frame)

(defcustom fido-frame-left 0.5
  "Child frame left offset as a fraction of the parent frame."
  :type 'number :group 'fido-frame)

(defcustom fido-frame-top 0.3
  "Child frame top offset as a fraction of the parent frame."
  :type 'number :group 'fido-frame)

(defcustom fido-frame-max-height (or completions-max-height 10)
  "Maximum height of the child frame in lines."
  :type 'integer :group 'fido-frame)

(defun fido-frame--init ()
  "Create a new minibuffer child frame."
  (setq fido-frame--frame
        (make-frame
         `((parent-frame . ,(selected-frame))
           (undecorated . t) (z-group . above)
           (minibuffer . only)
           (left . ,fido-frame-left) (top . ,fido-frame-top)
           (width . ,fido-frame-width) (height . 1)
           (left-fringe . 15) (right-fringe . 0)
           (child-frame-border-width . 2)
           (background-color . ,(face-background 'tooltip))))))

(defun fido-frame-setup ()
  "Setup minibuffer in centered child frame."
  (unless (frame-live-p fido-frame--frame)
    (fido-frame--init))
  ;; Reset frame hegiht
  (set-frame-height fido-frame--frame 1)
  (select-frame-set-input-focus fido-frame--frame)
  (make-frame-visible fido-frame--frame)
  ;; Prevent minibuffer from moving to another frame when user clicks
  ;; elsewhere, which would leave the child frame blank.
  (setq fido-frame-saved-minibuffer-follow minibuffer-follows-selected-frame
        minibuffer-follows-selected-frame nil))

(defun fido-frame-resize ()
  "Resize child frame to fit completions count."
  (set-frame-height fido-frame--frame
                    (if-let* ((s (and (boundp 'icomplete-overlay)
                                      (overlay-get icomplete-overlay 'after-string))))
                        (min fido-frame-max-height (1+ (cl-count ?\n s)))
                      1)))

(defun fido-frame--max-mini-lines (_orig-fun &optional _frame)
  "Return `fido-frame-max-height' so icomplete positions correctly."
  fido-frame-max-height)

(defun fido-frame-exit ()
  "Handle minibuffer exit."
  (when-let* ((frame fido-frame--frame)
              ((frame-live-p frame))
              (parent (frame-parameter frame 'parent-frame)))
    (make-frame-invisible frame)
    (when (frame-live-p parent)
      (select-frame-set-input-focus parent)))
  ;; Restore minibuffer-follows-selected-frame so it's not permanently
  ;; nil after a minibuffer session.
  (setq minibuffer-follows-selected-frame fido-frame-saved-minibuffer-follow))

;;;###autoload
(define-minor-mode fido-frame-mode
  "Show fido minibuffer completions in a centered child frame."
  :global t
  (if fido-frame-mode
      (progn
        (add-hook 'minibuffer-setup-hook #'fido-frame-setup)
        (add-hook 'minibuffer-exit-hook #'fido-frame-exit)
        (advice-add 'icomplete-exhibit :after #'fido-frame-resize)
        (advice-add 'max-mini-window-lines :around #'fido-frame--max-mini-lines))
    (remove-hook 'minibuffer-setup-hook #'fido-frame-setup)
    (remove-hook 'minibuffer-exit-hook #'fido-frame-exit)
    (advice-remove 'icomplete-exhibit #'fido-frame-resize)
    (advice-remove 'max-mini-window-lines #'fido-frame--max-mini-lines)
    (when (frame-live-p fido-frame--frame)
      (delete-frame fido-frame--frame)
      (setq fido-frame--frame nil))))

(provide 'fido-frame)
;;; fido-frame.el ends here
