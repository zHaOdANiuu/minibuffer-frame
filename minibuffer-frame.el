;;; minibuffer-frame.el --- Fido minibuffer in centered child frame -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Daniu Zhao

;; Author: Daniu Zhao <zhaodaniu1@gmail.com>
;; Assisted-by: DeepSeek:DeepSeek-v4-pro
;; Homepage: https://github.com/zHaOdANiuu/minibuffer-frame
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
;;   (require 'minibuffer-frame)
;;   (minibuffer-frame-mode 1)

;;; Code:

(require 'cl-lib)

(defvar minibuffer-frame--frame nil
  "The child frame used as a dedicated minibuffer window.")

(defvar minibuffer-frame--saved-minibuffer-follow t
  "Saved value of `minibuffer-follows-selected-frame' to restore on exit.")

(defvar minibuffer-frame--depth 0
  "Nesting depth of active minibuffers (0 = none).")

(defvar minibuffer-frame--skip-restore t)

(defgroup minibuffer-frame nil
  "Display fido completions in a centered child frame."
  :group 'convenience
  :prefix "minibuffer-frame-")

(defcustom minibuffer-frame-width 0.5
  "Child frame width as a fraction of the parent frame."
  :type 'number :group 'minibuffer-frame)

(defcustom minibuffer-frame-top 0.3
  "Child frame top offset as a fraction of the parent frame."
  :type 'number :group 'minibuffer-frame)

(defcustom minibuffer-frame-max-height (or completions-max-height 10)
  "Maximum height of the child frame in lines."
  :type 'integer :group 'minibuffer-frame)

(defun minibuffer-frame--init ()
  "Create a new minibuffer child frame."
  (setq minibuffer-frame--frame
        (make-frame
         `((parent-frame . ,(selected-frame))
           (undecorated . t) (z-group . above)
           (minibuffer . only)
           (left . 0) (top . ,minibuffer-frame-top)
           (width . ,minibuffer-frame-width) (height . 1)
           (left-fringe . 15) (right-fringe . 0)
           (child-frame-border-width . 2)
           (background-color . ,(face-background 'tooltip)))))
  (let ((pf (frame-parent minibuffer-frame--frame)))
    (set-frame-position
     minibuffer-frame--frame
     (/ (- (frame-pixel-width pf) (frame-pixel-width minibuffer-frame--frame)) 2)
     (round (* (frame-text-height pf) minibuffer-frame-top)))))

(defun minibuffer-frame--resize ()
  "Resize child frame to fit completions count."
  (set-frame-height minibuffer-frame--frame
                    (if-let* ((s (and (boundp 'icomplete-overlay)
                                      (overlay-get icomplete-overlay 'after-string))))
                        (min minibuffer-frame-max-height (1+ (cl-count ?\n s)))
                      1)))

(defun minibuffer-frame--max-mini-lines (_orig-fun &optional _frame)
  "Return `minibuffer-frame-max-height' so icomplete positions correctly."
  minibuffer-frame-max-height)

(defun minibuffer-frame--other-window (orig-fn &rest args)
  "Around advice for `other-window' keeping focus on the active minibuffer.
ORIG-FN and ARGS are the original function and its arguments.  Switching
windows while the minibuffer child frame is selected moves focus to the
parent frame; otherwise focus is returned to the child frame when the
switch does not change the selected window."
  (if (and (eq (selected-frame) minibuffer-frame--frame)
           (cl-plusp minibuffer-frame--depth))
      (let ((parent (frame-parent minibuffer-frame--frame)))
        (when (frame-live-p parent)
          (setq minibuffer-frame--skip-restore nil)
          (select-frame-set-input-focus parent)
          (select-window (car (window-list parent)))
          (run-with-timer 0.1 nil (lambda () (setq minibuffer-frame--skip-restore t)))))
    (let ((start (selected-window)))
      (apply orig-fn args)
      (when (and (eq (selected-window) start)
                 (cl-plusp minibuffer-frame--depth)
                 (frame-live-p minibuffer-frame--frame))
        (select-frame-set-input-focus minibuffer-frame--frame)))))

(defun minibuffer-frame--restore-focus ()
  "Restore input focus to the minibuffer child frame after focus changes."
  (when (and minibuffer-frame--skip-restore
             (cl-plusp minibuffer-frame--depth)
             (frame-live-p minibuffer-frame--frame))
    (select-frame-set-input-focus minibuffer-frame--frame)))

(defun minibuffer-frame-setup ()
  "Setup minibuffer in centered child frame."
  (unless (frame-live-p minibuffer-frame--frame)
    (minibuffer-frame--init))
  (let ((first (zerop minibuffer-frame--depth)))
    ;; Only reset height and save state for the outermost minibuffer.
    (when first
      (set-frame-height minibuffer-frame--frame 1))
    (cl-incf minibuffer-frame--depth)
    (select-frame-set-input-focus minibuffer-frame--frame)
    (make-frame-visible minibuffer-frame--frame)
    (when first
      (setq minibuffer-frame--saved-minibuffer-follow minibuffer-follows-selected-frame
            minibuffer-follows-selected-frame nil))))

(defun minibuffer-frame-exit ()
  "Handle minibuffer exit; recursive exits keep the frame visible."
  (cl-decf minibuffer-frame--depth)
  (setq minibuffer-frame--depth (max 0 minibuffer-frame--depth))
  (when (zerop minibuffer-frame--depth)
    (when-let* ((frame minibuffer-frame--frame)
                ((frame-live-p frame))
                (parent (frame-parameter frame 'parent-frame)))
      (make-frame-invisible frame)
      (when (frame-live-p parent)
        (select-frame-set-input-focus parent)))
    (setq minibuffer-follows-selected-frame minibuffer-frame--saved-minibuffer-follow)))

;;;###autoload
(define-minor-mode minibuffer-frame-mode
  "Show fido minibuffer completions in a centered child frame."
  :global t
  (if minibuffer-frame-mode
      (progn
        (add-hook 'minibuffer-setup-hook #'minibuffer-frame-setup)
        (add-hook 'minibuffer-exit-hook #'minibuffer-frame-exit)
        (advice-add 'icomplete-exhibit :after #'minibuffer-frame--resize)
        (advice-add 'max-mini-window-lines :around #'minibuffer-frame--max-mini-lines)
        (advice-add 'other-window :around #'minibuffer-frame--other-window)
        (add-function :after after-focus-change-function #'minibuffer-frame--restore-focus))
    (remove-hook 'minibuffer-setup-hook #'minibuffer-frame-setup)
    (remove-hook 'minibuffer-exit-hook #'minibuffer-frame-exit)
    (advice-remove 'icomplete-exhibit #'minibuffer-frame--resize)
    (advice-remove 'max-mini-window-lines #'minibuffer-frame--max-mini-lines)
    (advice-remove 'other-window #'minibuffer-frame--other-window)
    (remove-function after-focus-change-function #'minibuffer-frame--restore-focus)
    (setq minibuffer-frame--depth 0
          minibuffer-follows-selected-frame minibuffer-frame--saved-minibuffer-follow)
    (when (frame-live-p minibuffer-frame--frame)
      (delete-frame minibuffer-frame--frame)
      (setq minibuffer-frame--frame nil))))

(provide 'minibuffer-frame)
;;; minibuffer-frame.el ends here
