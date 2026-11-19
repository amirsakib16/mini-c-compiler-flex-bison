#!/bin/bash
bison -d -y -v 22299222.y
echo 'Generated the parser C file as well the header file'
g++ -w -c -o y.tab.o y.tab.c
echo 'Generated the parser object file'
flex 22299222.l
echo 'Generated the scanner C file'
g++ -fpermissive -w -c -o lex.yy.o lex.yy.c
echo 'Generated the scanner object file'
g++ -o a.out y.tab.o lex.yy.o
echo 'All ready, running'
./a.out input.c
