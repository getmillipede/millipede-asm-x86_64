NAME=millipede
SRC=main.s

AS=nasm
ASFLAGS=-f bin -D _OS_`uname`
RM=rm -fr
CHMOD=chmod +x

all:
	$(AS) $(ASFLAGS) -o $(NAME) $(SRC)
	$(CHMOD) $(NAME)

clean:
	$(RM) $(NAME)

re: clean all
