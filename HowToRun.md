1. Genera i file C++ da Bison:
    bison -d parser.y  (Crea parser.tab.c e parser.tab.h)

2. Genera i file C++ da Flex:
    flex lexer.l (Crea lex.yy.c)

3. Compila tutto insieme:
    g++ lex.yy.c parser.tab.c -o compiler

4. Esegui: 
    ./compiler 