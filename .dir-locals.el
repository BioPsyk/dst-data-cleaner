((nil .
      ((eval .
             (progn
               (defun dstdc/tmux-pane-cmd (pane cmd)
                 "Runs the given shell command in a subshell inside a tmux pane."
                 (interactive)
                 (let* ((resolved-pane (concat "dst-data-cleaner:" pane))
                        (resolved-cmd (format "'%s'" cmd))
                        (cmd-parts (list "tmux"
                                         "send-keys"
                                         "-t"
                                         resolved-pane
                                         resolved-cmd
                                         "C-m")))
                   (shell-command (format "tmux clear-history -t %s" resolved-pane))
                   (shell-command (mapconcat 'identity cmd-parts " "))))

               (defun get-file-in-project (filename)
                 "Gets absolute path to file inside the project"
                 (interactive "P")
                 (expand-file-name filename (projectile-project-root)))

               (defun dstdc/run-sh-scratch ()
                 "Kills all processes and tmux"
                 (interactive)
                 (dstdc/tmux-pane-cmd "0.0" "C-c")
                 (dstdc/tmux-pane-cmd "0.0" "clear")
                 (dstdc/tmux-pane-cmd "0.0" "./tmp/scratch.sh"))

               (defun dstdc/kill-dev-env ()
                 "Kills all processes and tmux"
                 (interactive)
                 (dstdc/tmux-pane-cmd "0.0" "C-c")
                 (dstdc/tmux-pane-cmd "0.0" "tmux kill-session"))

               (global-set-key (kbd "<f1>") 'dstdc/run-sh-scratch)
               (global-set-key (kbd "<f12>") 'dstdc/kill-dev-env)

               )))))
