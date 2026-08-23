;;; minibuffer-frame.el --- Minibuffer in centered child frame -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Daniu Zhao

;; Author: Daniu Zhao <zhaodaniu1@gmail.com>
;; Homepage: https://github.com/zHaOdANiuu/minibuffer-frame
;; Version: 0.0.3
;; Package-Requires: ((emacs "28.1"))
;; Keywords: convenience, minibuffer, child-frame

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

;; Display Fido/icomplete minibuffer in a centered child frame.
;;
;; Enable with:
;;
;;   (require 'minibuffer-frame)
;;   (minibuffer-frame-mode 1)
;;
;; Customize with `M-x customize-group RET minibuffer-frame RET'.

;;; Code:

(require 'cl-lib)
(require 'icomplete)

(defvar minibuffer-frame--frame nil
  "Child frame used for the active minibuffer.")

(defvar minibuffer-frame--saved-minibuffer-follow nil
  "Saved value of `minibuffer-follows-selected-frame'.")

(defvar minibuffer-frame--skip-focus nil
  "Non-nil while temporarily suppressing child-frame focus.")

(defgroup minibuffer-frame nil
  "Display Fido completions in a centered child frame."
  :group 'convenience
  :prefix "minibuffer-frame-")

(defcustom minibuffer-frame-width 0.5
  "Width of the child frame as a fraction of its parent frame."
  :type 'number :group 'minibuffer-frame)

(defcustom minibuffer-frame-top 0.3
  "Top offset of the child frame as a fraction of its parent frame."
  :type 'number :group 'minibuffer-frame)

(defun minibuffer-frame--live-p ()
  "Return non-nil when the minibuffer frame is live."
  (and (framep minibuffer-frame--frame)
       (frame-live-p minibuffer-frame--frame)))

(defun minibuffer-frame--clear ()
  "Delete and clear the minibuffer frame when it is live."
  (when (minibuffer-frame--live-p)
    (delete-frame minibuffer-frame--frame))
  (setq minibuffer-frame--frame nil))

(defun minibuffer-frame--init ()
  "Create and center the minibuffer child frame."
  (setq minibuffer-frame--frame
        (make-frame
         `((parent-frame . ,(selected-frame))
           (undecorated . t) (z-group . above) (minibuffer . only)
           (width . ,minibuffer-frame-width) (height . 1)
           (left-fringe . 15) (right-fringe . 0) (child-frame-border-width . 2)
           (background-color . ,(face-background 'tooltip)))))
  (let ((pf (frame-parent minibuffer-frame--frame)))
    (set-frame-position
     minibuffer-frame--frame
     (floor (- (frame-pixel-width pf) (frame-pixel-width minibuffer-frame--frame)) 2)
     (floor (* (frame-text-height pf) minibuffer-frame-top)))))

(defun minibuffer-frame--setup ()
  "Show and focus the child frame for the active minibuffer."
  (unless (and (minibuffer-frame--live-p)
               (eq (frame-parent minibuffer-frame--frame)
                   (selected-frame)))
    (minibuffer-frame--clear)
    (minibuffer-frame--init))
  (when (and (= (minibuffer-depth) 1)
             (minibuffer-frame--live-p))
    (make-frame-visible minibuffer-frame--frame)
    (select-frame-set-input-focus minibuffer-frame--frame)
    (setq minibuffer-frame--saved-minibuffer-follow
          minibuffer-follows-selected-frame)
    (setq minibuffer-follows-selected-frame nil))
  (advice-add 'other-window :around #'minibuffer-frame--other-window)
  (add-function :after after-focus-change-function #'minibuffer-frame--handle-focus))

(defun minibuffer-frame--exit ()
  "Hide the child frame after the outermost minibuffer exits."
  (when (and (< (minibuffer-depth) 2)
             (minibuffer-frame--live-p))
    (make-frame-invisible minibuffer-frame--frame)
    (set-frame-height minibuffer-frame--frame 1)
    (setq minibuffer-follows-selected-frame
          minibuffer-frame--saved-minibuffer-follow)
    (advice-remove 'other-window #'minibuffer-frame--other-window)
    (remove-function after-focus-change-function #'minibuffer-frame--handle-focus)))

(defun minibuffer-frame--icomplete-exhibit ()
  "Resize the child frame to fit icomplete completions."
  (when (minibuffer-frame--live-p)
    (set-frame-height
     minibuffer-frame--frame
     (min (+ (length icomplete--scrolled-past)
             (safe-length completion-all-sorted-completions))
          (or completions-max-height 10)))))

(defun minibuffer-frame--max-mini-window-lines (_orig-fn &optional _frame)
  "Return `completions-max-height' for `max-mini-window-lines'."
  (or completions-max-height 10))

(defun minibuffer-frame--handle-focus ()
  "Restore focus to the child frame after focus changes."
  (when (and (not minibuffer-frame--skip-focus)
             (minibuffer-frame--live-p)
             (active-minibuffer-window))
    (select-frame-set-input-focus minibuffer-frame--frame)))

(defun minibuffer-frame--other-window (orig-fn &rest args)
  "Redirect ORIG-FN to the child frame.  Pass ARGS to `other-window'."
  (cond
   ((and (minibuffer-frame--live-p)
         (eq (selected-frame) minibuffer-frame--frame))
    (setq minibuffer-frame--skip-focus t)
    (select-frame-set-input-focus (frame-parent minibuffer-frame--frame))
    (run-with-timer 0.1 nil (lambda () (setq minibuffer-frame--skip-focus nil))))
   (t
    (let ((start (selected-window)))
      (apply orig-fn args)
      (when (and (eq (selected-window) start)
                 (minibuffer-frame--live-p))
        (select-frame-set-input-focus minibuffer-frame--frame))))))

;;;###autoload
(define-minor-mode minibuffer-frame-mode
  "Display Fido minibuffer completions in a centered child frame."
  :global t
  (if minibuffer-frame-mode
      (progn
        (add-hook 'minibuffer-setup-hook #'minibuffer-frame--setup)
        (add-hook 'minibuffer-exit-hook #'minibuffer-frame--exit)
        (advice-add 'icomplete-exhibit :after #'minibuffer-frame--icomplete-exhibit)
        (advice-add 'max-mini-window-lines :around #'minibuffer-frame--max-mini-window-lines))
    (remove-hook 'minibuffer-setup-hook #'minibuffer-frame--setup)
    (remove-hook 'minibuffer-exit-hook #'minibuffer-frame--exit)
    (advice-remove 'icomplete-exhibit #'minibuffer-frame--icomplete-exhibit)
    (advice-remove 'max-mini-window-lines #'minibuffer-frame--max-mini-window-lines)
    (minibuffer-frame--clear)))

(provide 'minibuffer-frame)
;;; minibuffer-frame.el ends here
