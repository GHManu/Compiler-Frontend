%{
#include "parser.tab.h"
#include <iostream>
void yyerror(const char *s);

// eseguito automaticamente prima di ogni azione
#define YY_USER_ACTION \
    yylloc.first_line   = yylloc.last_line   = yylineno; \
    yylloc.first_column = yylloc.last_column + 1; \
    yylloc.last_column  = yylloc.first_column + yyleng - 1;


%}

%option noyywrap yylineno

%x COMMENTO

%%

"/*"           { BEGIN(COMMENTO); }
<COMMENTO>"*/" { BEGIN(INITIAL); }
<COMMENTO>\n   { /* ignora newline */ }
<COMMENTO>.    { /* ignora tutto il resto */ }
"//"  { /* ignora */ }  


"if" { return T_IF;}
"(" { return T_LPAREN;}
")" { return T_RPAREN;}
"{" { return T_LBRACE;}
"}" { return T_RBRACE;}

"=="    { return T_EQ; }
"!="    { return T_NE; }
"<"     { return T_LT; }
">"     { return T_GT; }
"<="    { return T_LE; }
">="    { return T_GE; }

"int"                   { return T_INT; }
"float"                 { return T_FLOAT; }
[0-9]+                  { 
                            long long val = strtoll(yytext, NULL, 10);
                            if (val > 2147483647LL || val < -2147483648LL) {
                                yyerror("Overflow: intero fuori range");
                                return T_ERROR;
                            }
                            yylval.num = (int)val;
                            return T_INT_NUMBER; 
                        }
[0-9]+"."[0-9]*         {
                            double val = strtod(yytext, NULL);
                            if (val > 3.4028235e+38) {
                                yyerror("Overflow: float fuori range");
                                return T_ERROR;
                            }
                            yylval.fnum = (float)val;
                            return T_FLOAT_NUMBER;
                        }
[a-zA-Z_][a-zA-Z0-9_]* { yylval.str = strdup(yytext); return T_ID; }
"="                     { return T_ASSIGN; }
"-"                     { return T_MINUS; }
"+"                     { return T_PLUS; }
";"                     { return T_SEMICOLON; }
[ \t\n]                 { /* ignora */ }
.                       { std::cerr << "Carattere ignoto: " << yytext << std::endl; }
%%