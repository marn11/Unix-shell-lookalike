# Minishell

A small Unix shell written in C as part of the 42 `minishell` project.

This project is organized around two major parts:

- `parsing/`: tokenizing, syntax checks, expansion preparation, heredoc preparation, and building the internal command list.
- `execution/`: running commands, handling builtins, resolving paths, setting up redirections, creating pipelines, and managing processes/signals.

## Contribution Split

This was a group project with a clear split of responsibilities:

- I worked on the **execution** part.
- My teammate worked on the **parsing** part.

Because of that, this README focuses mainly on the execution layer and the technical decisions behind it.

## Project Structure

```text
.
├── parsing/
├── execution/
│   ├── src/
│   └── utils/
├── main.c
├── minishell.h
└── Makefile
```

## How Execution Works

After parsing produces the internal linked list of commands, the execution layer takes over:

1. The shell updates its environment state and resolves `PATH`.
2. It decides whether the command is a builtin or an external program.
3. It applies input/output redirections.
4. If there is a pipeline, it creates the required pipes and child processes.
5. It executes builtins directly when needed, or launches external programs with `execve`.
6. The parent waits for child processes and updates the shell exit status.

## Technical Details Of The Execution Part

### Builtins vs external commands

One of the first execution decisions is whether a command is a builtin such as `cd`, `pwd`, `echo`, `env`, `export`, `unset`, or `exit`.

- A **single builtin** is executed in the parent process so it can modify shell state directly.
- This matters especially for commands like `cd`, `export`, `unset`, and `exit`, because their effects must persist in the shell itself.
- If the builtin is part of a pipeline, it is executed in a child process instead, because the pipeline needs separate process contexts.

This logic appears in `exec()` and `onecmd_builtin()`.

### PATH resolution

For external commands, the shell resolves the executable path manually:

- If the command starts with `/` or `.`, it is treated as a direct path.
- Otherwise, the shell searches through the directories stored in `PATH`.
- The first executable match found with `access(..., X_OK)` is used.
- If nothing is found, the shell exits the child with status `127`.

This behavior is implemented in `get_cmd_path()`.

### Redirections

The execution layer also handles:

- input redirection with `<`
- output redirection with `>`
- append redirection with `>>`
- heredoc input with `<<`

The shell opens the target file and then redirects standard input or output using `dup2`. After the duplication, the temporary file descriptor is closed. The redirection tokens are then removed from the command arguments so the executed command only receives the real parameters.

This is handled mainly in `handle_redirs()`, `handle_redir_in()`, `handle_redir_out()`, and `handle_append()`.

### Pipelines

For commands connected with `|`, the execution layer:

- creates a new pipe with `pipe()`
- forks a child process for each command
- connects the previous command's output to the next command's input
- closes unused file descriptors in both parent and child
- waits for all children at the end

The functions `cmd_process()`, `child_io()`, and `parent_io()` are the core of this pipeline logic.

## Important System Calls

### `fork()`

`fork()` creates a child process by duplicating the current process.

In this shell, `fork()` is used when executing commands in pipelines and when launching external programs. Each child gets its own process context, which is necessary so that commands can run concurrently and exchange data through pipes without replacing the shell process itself.

Why it matters:

- the parent shell must stay alive
- each command in a pipeline needs its own process
- signal behavior often differs between parent and child

### `execve()`

`execve()` replaces the current process image with a new program.

In this project, once a child process has the correct input/output setup and the command path is resolved, `execve()` is called to run the actual executable. If it succeeds, the child process becomes that program. If it fails, the shell reports the error and exits the child with the appropriate status code.

Why it matters:

- `fork()` creates the child
- `execve()` turns that child into the requested command
- together they form the classic shell execution model

### `dup2()`

`dup2(oldfd, newfd)` duplicates a file descriptor onto a specific target descriptor.

This is one of the most important calls in shell execution because standard streams are just file descriptors:

- `0` for standard input
- `1` for standard output
- `2` for standard error

In this minishell, `dup2()` is used to:

- redirect input from a file to `stdin`
- redirect output to a file
- connect a pipe's read end to `stdin`
- connect a pipe's write end to `stdout`
- restore the original descriptors after builtin execution

Without `dup2()`, redirections and pipelines would not work.

### `pipe()`

`pipe()` creates a pair of file descriptors:

- one end for reading
- one end for writing

The shell uses this to connect commands like:

```bash
ls | wc -l
```

Here, the first command writes into the pipe and the second command reads from it. The execution layer must also close the unused ends carefully, otherwise processes may hang waiting for input that never properly closes.

## Signals And Exit Status

Execution also includes process control details beyond simply launching commands:

- the parent ignores some interactive signals while children run
- children restore default signal behavior
- the shell collects child exit codes with `waitpid`
- if a command is terminated by a signal, the shell converts that into the expected shell status code

This behavior is implemented in `setup_signals()` and `children_wait()`.

## Useful Resources

These references were especially useful while working on the execution part:

- [Writing Your Own Shell - Purdue Systems Programming Book, Chapter 5](https://www.cs.purdue.edu/homes/grr/SystemsProgrammingBook/Book/Chapter5-WritingYourOwnShell.pdf)
- [`fork(2)` man page](https://man7.org/linux/man-pages/man2/fork.2.html)
- [`execve(2)` man page](https://man7.org/linux/man-pages/man2/execve.2.html)
- [`dup2(2)` man page](https://man7.org/linux/man-pages/man2/dup.2.html)
- [`pipe(2)` man page](https://man7.org/linux/man-pages/man2/pipe.2.html)
- [`waitpid(2)` man page](https://man7.org/linux/man-pages/man2/waitpid.2.html)

## Build

### Install Readline

This project uses the `readline` library for the interactive prompt, command history, and line editing.

The easiest setup is on macOS with Homebrew, because the current `Makefile` already expects Homebrew's `readline` include and library paths.

#### macOS

```bash
brew install readline
make
./minishell
```

If `brew` is not installed yet, install Homebrew first and then run the commands above.

#### Ubuntu / Debian

```bash
sudo apt update
sudo apt install libreadline-dev
make
./minishell
```

#### Fedora

```bash
sudo dnf install readline-devel
make
./minishell
```

### Important note for Linux users

The provided `Makefile` currently uses:

```makefile
READLINE_L = $(shell brew --prefix readline)/lib
READLINE_I = $(shell brew --prefix readline)/include
```

So it is already tailored for a Homebrew-based setup. On Linux, after installing the `readline` development package, you may need to adapt the `Makefile` if your system does not use Homebrew paths.

In practice, the easiest experience is:

- use `brew install readline` on macOS
- or install the Linux development package and update the `Makefile` paths if needed

### Compile and run

```bash
make
./minishell
```

If compilation fails because of `readline` include or linker errors, the first thing to check is whether the library is installed and whether the include/library paths in the `Makefile` match your machine.

## Final Note

This project helped me understand how a shell really works at the process level: creating children, wiring file descriptors, executing programs, and preserving shell state correctly when builtins are involved. My main work was in the execution layer, while my teammate focused on the parsing side of the shell.
