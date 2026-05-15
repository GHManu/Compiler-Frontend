%{
#include <iostream>
#include "driver.h"

extern int yylex(Driver& drv);
void yyerror(Driver& drv,const char *s);
extern FILE* yyin; 
%}

%param { Driver& drv }

%locations

%union {
    int   num;
    float fnum;
    char *str;
    bool  boolean;
    Nodo *nodo;
    std::vector<Nodo*>* list;
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


%type <nodo> espressione
%type <nodo> istruzione
%type <nodo> condizione
%type <list> blocco lista_istruzioni

%left T_PLUS T_MINUS
%left T_EQ T_NE T_LT T_GT T_LE T_GE

%%

programma:
    lista_istruzioni
    {
        drv.programma.istruzioni = std::move(*$1);
        delete $1;
    }
    ;

lista_istruzioni:
    istruzione lista_istruzioni
    {
        $2->insert($2->begin(), $1);  // <- inserisce in testa per mantenere l'ordine
        $$ = $2;
    }
    | /* vuoto */
    {
        $$ = new std::vector<Nodo*>();
    }
    ;

blocco:
    T_LBRACE lista_istruzioni T_RBRACE  { $$ = $2; }
    | istruzione { $$ = new std::vector<Nodo*>({$1}); }
    ;

istruzione:
    T_INT T_ID T_SEMICOLON
    {
        if (drv.tabella.count($2)) yyerror(drv, "Variabile già dichiarata");
        else {
            drv.tabella[$2] = { TIPO_INT, false, 0 };
            $$ = new NodoDichiara("int", $2, nullptr);
        }
    }
    | T_INT T_ID T_ASSIGN espressione T_SEMICOLON
    {
        if (drv.tabella.count($2)) yyerror(drv, "Variabile già dichiarata");
        else {
            drv.tabella[$2] = { TIPO_INT, true, 0 };
            $$ = new NodoDichiara("int", $2, $4);  // $4 è già un Nodo*
        }
    }
    | T_FLOAT T_ID T_SEMICOLON
    {
        if (drv.tabella.count($2)) yyerror(drv, "Variabile già dichiarata");
        else {
            drv.tabella[$2] = { TIPO_FLOAT, false, 0.0f };
            $$ = new NodoDichiara("float", $2, nullptr);
        }
    }
    | T_FLOAT T_ID T_ASSIGN espressione T_SEMICOLON
    {
        if (drv.tabella.count($2)) yyerror(drv, "Variabile già dichiarata");
        else {
            drv.tabella[$2] = { TIPO_FLOAT, true, 0.0f };
            $$ = new NodoDichiara("float", $2, $4);
        }
    }
    | T_ID T_ASSIGN espressione T_SEMICOLON
    {
        if (!drv.tabella.count($1)) yyerror(drv, "Variabile non dichiarata");
        else {
            drv.tabella[$1].inizializzato = true;
            $$ = new NodoAssegna($1, $3);
        }
    }
    | T_IF T_LPAREN condizione T_RPAREN blocco
    {
        $$ = new NodoIf($3, $5);  // condizione e blocco sono già Nodo*
    }
    ;

condizione:
    espressione T_EQ espressione { $$ = new NodoBinop('=', $1, $3); }
    | espressione T_NE espressione { $$ = new NodoBinop('!', $1, $3); }
    | espressione T_LT espressione { $$ = new NodoBinop('<', $1, $3); }
    | espressione T_GT espressione { $$ = new NodoBinop('>', $1, $3); }
    | espressione T_LE espressione { $$ = new NodoBinop('l', $1, $3); }
    | espressione T_GE espressione { $$ = new NodoBinop('g', $1, $3); }
    | espressione                  { $$ = $1; }
    ;

espressione:
    T_INT_NUMBER   { $$ = new NodoIntero($1); }
    | T_FLOAT_NUMBER { $$ = new NodoFloat($1); }
    | T_ID
    {
        if (!drv.tabella.count($1)) {
            yyerror(drv, "Variabile non dichiarata");
            $$ = nullptr;
        } else if (!drv.tabella[$1].inizializzato) {
            yyerror(drv, "Variabile usata prima di essere inizializzata");
            $$ = nullptr;
        } else {
            $$ = new NodoID($1);
        }
    }
    | espressione T_PLUS espressione { $$ = new NodoBinop('+', $1, $3); }
    | T_MINUS espressione            { $$ = new NodoUnario($2); }
    ;

%%

void yyerror(Driver& drv,const char *s) {
    std::cerr << yylloc.first_line << ":" << yylloc.first_column
              << ": Errore: " << s << std::endl;
}

int main(int argc, char* argv[]) {
    Driver drv;

    if (argc > 1) {
        // legge da file se passi un argomento
        FILE* f = fopen(argv[1], "r");
        if (!f) {
            std::cerr << "Errore: file '" << argv[1] << "' non trovato\n";
            return 1;
        }
        yyin = f;  // yyin è la variabile globale di Flex per l'input
        std::cout << "Leggo da file: " << argv[1] << "\n";
    } else {
        // altrimenti stdin come prima
        std::cout << "Inserisci codice (Ctrl+D per terminare):\n";
    }

    int risultato = yyparse(drv);
    if (argc > 1) fclose(yyin);

    if (risultato == 0)
        drv.programma.print();

    return 0;
}