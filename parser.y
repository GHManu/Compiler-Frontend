%{
#include <iostream>
#include "driver.h"

extern int yylex(Driver& drv);
void yyerror(Driver& drv,const char *s);
%}

%param { Driver& drv }

%locations

%union {
    int   num;
    float fnum;
    char *str;
    bool  boolean;
}

%token <num> T_INT_NUMBER
%token <fnum> T_FLOAT_NUMBER
%token <str> T_ID
%token T_SEMICOLON

%token  T_ERROR

%token T_INT T_FLOAT 

%token T_ASSIGN T_PLUS T_MINUS

%token T_IF T_LPAREN T_RPAREN T_LBRACE T_RBRACE
%token T_EQ T_NE T_LT T_GT T_LE T_GE


%type <fnum> espressione
%type <boolean> condizione

%left T_PLUS T_MINUS
%left T_EQ T_NE T_LT T_GT T_LE T_GE

%%

programma:
    lista_istruzioni
    ;

lista_istruzioni:
    istruzione lista_istruzioni
    | /* vuoto */
    ;

istruzione:
    T_INT T_ID T_SEMICOLON
    {
        if (drv.tabella.count($2)) yyerror(drv,"Variabile già dichiarata");
        else {
            drv.tabella[$2] = { TIPO_INT, false, 0 };
            std::cout << "[PARSER] Dichiarato int: " << $2 << std::endl;
        }
    }
    | T_INT T_ID T_ASSIGN espressione T_SEMICOLON
    {
        if (drv.tabella.count($2)) yyerror(drv,"Variabile già dichiarata");
        else {
            drv.tabella[$2] = { TIPO_INT, true, $4 };
            std::cout << "[PARSER] " << $2 << " = " << $4 << std::endl;
        }
    }
    | T_FLOAT T_ID T_SEMICOLON
    {
        if (drv.tabella.count($2)) yyerror(drv,"Variabile già dichiarata");
        else {
            drv.tabella[$2] = { TIPO_FLOAT, false, 0.0f };
            std::cout << "[PARSER] Dichiarato float: " << $2 << std::endl;
        }
    }
    | T_FLOAT T_ID T_ASSIGN espressione T_SEMICOLON
    {
        if (drv.tabella.count($2)) yyerror(drv,"Variabile già dichiarata");
        else {
            drv.tabella[$2] = { TIPO_FLOAT, true, $4 };
            std::cout << "[PARSER] " << $2 << " = " << $4 << std::endl;
        }
    }
    | T_ID T_ASSIGN espressione T_SEMICOLON
    {
        if (!drv.tabella.count($1)) yyerror(drv,"Variabile non dichiarata");
        else {
            drv.tabella[$1].inizializzato = true;
            drv.tabella[$1].valore = $3;
            std::cout << "[PARSER] Assegnamento: " << $1 << " = " << $3 << std::endl;
        }
    }
    | T_IF T_LPAREN condizione T_RPAREN { 
        std::cout << "[PARSER] Valuto IF: la condizione è " << ($3 ? "VERA" : "FALSA") << std::endl;
    } blocco
    ;

condizione:
    espressione T_EQ espressione { $$ = ($1 == $3); }
    | espressione T_NE espressione { $$ = ($1 != $3); }
    | espressione T_LT espressione { $$ = ($1 < $3); }
    | espressione T_GT espressione { $$ = ($1 > $3); }
    | espressione T_LE espressione { $$ = ($1 <= $3); }
    | espressione T_GE espressione { $$ = ($1 >= $3); }
    | espressione                  { $$ = ($1 != 0); }
    ;

blocco:
    T_LBRACE lista_istruzioni T_RBRACE
    | istruzione 
    ;

espressione:
    T_INT_NUMBER   { $$ = (float)$1; }
    | T_FLOAT_NUMBER { $$ = $1; }
    | T_ID
    {
        if (!drv.tabella.count($1)) {
            yyerror(drv,"Variabile non dichiarata");
            $$ = 0;
        } else if (!drv.tabella[$1].inizializzato) {
            yyerror(drv,"Variabile usata prima di essere inizializzata");
            $$ = 0;
        } else {
            $$ = drv.tabella[$1].valore;
        }
    }
    | espressione T_PLUS espressione { $$ = $1 + $3; }
    | T_MINUS espressione           { $$ = -$2; }
    ;

%%

void yyerror(Driver& drv,const char *s) {
    std::cerr << yylloc.first_line << ":" << yylloc.first_column
              << ": Errore: " << s << std::endl;
}

int main() {
    Driver drv;
    std::cout << "Inserisci codice (es: int x = 10; if (x > 5) { x = x + 1; }):" << std::endl;
    return yyparse(drv);
}