// Command extractmail — Go host CLI wrapper around Python extract path + list-types.
// Full HTML extract still uses Node/Python reference path; Go provides a stable entry.
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

func main() {
	root := findRoot()
	py := filepath.Join(root, "python", "extractmail_stdin.py")
	if len(os.Args) > 1 && os.Args[1] == "fetch" {
		fetch := filepath.Join(root, "python", "fetch_mail.py")
		cmd := exec.Command("python3", append([]string{fetch}, os.Args[2:]...)...)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		cmd.Stdin = os.Stdin
		cmd.Env = append(os.Environ(), "PYTHONPATH="+filepath.Join(root, "python"))
		if err := cmd.Run(); err != nil {
			if ee, ok := err.(*exec.ExitError); ok {
				os.Exit(ee.ExitCode())
			}
			fmt.Fprintln(os.Stderr, err)
			os.Exit(2)
		}
		return
	}
	cmd := exec.Command("python3", append([]string{py}, os.Args[1:]...)...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	cmd.Env = append(os.Environ(), "PYTHONPATH="+filepath.Join(root, "python"))
	if err := cmd.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			os.Exit(ee.ExitCode())
		}
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
}

func findRoot() string {
	// go/cmd/extractmail → repo root
	exe, err := os.Executable()
	if err == nil {
		// when run via go run, prefer relative from cwd markers
		_ = exe
	}
	wd, _ := os.Getwd()
	// walk up looking for python/extractmail_stdin.py
	dir := wd
	for i := 0; i < 8; i++ {
		if _, err := os.Stat(filepath.Join(dir, "python", "extractmail_stdin.py")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	// from source layout go/cmd/extractmail
	dir = wd
	cand := filepath.Join(dir, "..", "..")
	if abs, err := filepath.Abs(cand); err == nil {
		if _, err := os.Stat(filepath.Join(abs, "python", "extractmail_stdin.py")); err == nil {
			return abs
		}
	}
	return wd
}
