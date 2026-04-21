NAME = minishell

SRC = main.c \
	parsing/syntax.c parsing/utils_syntax.c parsing/ft_split.c parsing/ft_split_spaces.c parsing/signals.c \
	parsing/split_cmd.c parsing/add_space.c parsing/parsing.c parsing/expanding.c parsing/expanding_utils.c \
	parsing/handle_heredoc.c parsing/heredoc_utils.c \
  	execution/src/envp.c execution/src/builtins.c	execution/src/cd.c execution/src/pwd.c execution/src/env.c \
  	execution/src/echo.c execution/src/execution.c execution/src/unset.c execution/src/export.c execution/src/exporthelp.c execution/src/redir.c \
  	execution/src/exit.c execution/src/utils.c execution/utils/utils1.c execution/utils/utils2.c execution/utils/utils3.c execution/utils/utils4.c \
	execution/src/exporthelp2.c execution/src/execution1.c execution/src/cdhelper.c execution/src/redirhelp.c execution/src/execution2.c execution/src/execution3.c \

OBJ = $(addprefix obj/, $(SRC:.c=.o))

HEADER = minishell.h execution/utils/utils.h

CC = cc

FLAG = -Wall -Wextra -Werror

UNAME_S := $(shell uname -s)
BREW := $(shell command -v brew 2>/dev/null)

ifeq ($(BREW),)
	READLINE_L =
	READLINE_I =
	READLINE_FLAGS = -lreadline
else
	READLINE_PREFIX := $(shell brew --prefix readline)
	READLINE_L = $(READLINE_PREFIX)/lib
	READLINE_I = $(READLINE_PREFIX)/include
	READLINE_FLAGS = -L $(READLINE_L) -I $(READLINE_I) -lreadline
endif

all: $(NAME)

obj/%.o: %.c $(HEADER)
	@mkdir -p $(dir $@)
	@($(CC) $(FLAG) $(if $(READLINE_I),-I $(READLINE_I)) -c $< -o $@)
	@printf "\rcompiling...\033[K"

$(NAME): $(OBJ)
	@($(CC) $(FLAG) $(OBJ) -o $(NAME) $(READLINE_FLAGS))
	@printf "\r\033[K\033[33mminishell compiled\033[0m\n"

clean:
	rm -rf obj

fclean: clean
	rm -rf $(NAME)

re: fclean all
