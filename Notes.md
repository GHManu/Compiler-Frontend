# Flex & Bison — Come funziona

## Il flusso generale

```
Testo sorgente → [Lexer/Flex] → Token → [Parser/Bison] → AST → print/visita
```

> **Regola pratica per aggiungere qualsiasi cosa:**
> 1. Dichiari il token in `parser.y`
> 2. Gli dai un valore nel `lexer.l`
> 3. Scrivi la semantica nelle azioni di `parser.y`

---

## 1. Analizzatore Lessicale — `lexer.l`

Il lexer legge il testo carattere per carattere e lo trasforma in **token**, cioè unità dotate di significato.

| Pattern | Cosa riconosce | Cosa fa |
|---|---|---|
| `"int"` | La parola chiave `int` | Restituisce `T_INT` |
| `[0-9]+` | Sequenza di cifre intere | `strtoll` + range check, restituisce `T_INT_NUMBER` |
| `[0-9]+"."[0-9]*` | Numero decimale | `strtod` + range check, restituisce `T_FLOAT_NUMBER` |
| `[a-zA-Z_][a-zA-Z0-9_]*` | Nome variabile | `strdup`, salva in `yylval.str`, restituisce `T_ID` |
| `[ \t\n]` | Spazi/tab/invio | Ignora |
| `"/*" ... "*/"` | Commento | Ignorato tramite stato `%x COMMENTO` |
| `.` | Qualsiasi altro carattere | Errore |

### Perché `strtoll`/`strtod` invece di `atoi`/`atof`?

`atoi` e `atof` non controllano nulla — convertono e basta. Se scrivi `999999999999` nel sorgente, `atoi` ti dà silenziosamente un risultato troncato. Il range check va fatto nel lexer, prima che il valore arrivi al parser:

```c
[0-9]+ {
    long long val = strtoll(yytext, NULL, 10);
    if (val > 2147483647LL || val < -2147483648LL) {
        yyerror(drv, "Overflow: intero fuori range");
        return T_ERROR;
    }
    yylval.num = (int)val;
    return T_INT_NUMBER;
}
```

L'idea è usare un tipo più grande (`long long`, `double`) per leggere il valore grezzo, controllare se sta nel range del tipo target, e solo allora fare il cast.

> **Nota:** il segno negativo non serve qui perché i letterali nel sorgente sono sempre positivi — il meno è gestito dalla regola `T_MINUS espressione` nel parser.

### Commenti — stato esclusivo

```lex
%x COMMENTO

%%

"/*"           { BEGIN(COMMENTO); }
<COMMENTO>"*/" { BEGIN(INITIAL); }
<COMMENTO>\n   { /* ignora */ }
<COMMENTO>.    { /* ignora */ }
```

`%x` dichiara uno stato **esclusivo** — in quello stato valgono solo le regole marcate con `<COMMENTO>`, tutte le altre vengono ignorate. Quando Flex vede `/*` entra nello stato, ignora tutto finché non trova `*/`, poi torna a `INITIAL`.

### `YY_DECL` e il driver

Con `%param { Driver& drv }` nel parser, Bison si aspetta che anche `yylex` riceva il driver. Devi dirlo esplicitamente a Flex con `YY_DECL`:

```lex
%{
#include "driver.h"
#include "parser.tab.h"
void yyerror(Driver& drv, const char *s);
#define YY_DECL int yylex(Driver& drv)
%}
```

Senza `YY_DECL`, Flex genera `int yylex()` senza parametri e Bison non riesce a passargli `drv`.

---

## 2. Analizzatore Sintattico — `parser.y`

Il parser riceve i token dal lexer e verifica che seguano le regole grammaticali del linguaggio.

### `%union` e `%token`

```yacc
%union {
    int                  num;      // per T_INT_NUMBER
    float                fnum;     // per T_FLOAT_NUMBER
    char                *str;      // per T_ID
    bool                 boolean;  // non più usato dopo AST (vedi sotto)
    Nodo                *nodo;     // per espressione, istruzione, condizione
    std::vector<Nodo*>  *list;     // per lista_istruzioni e blocco
}
```

`%union` è una `union` C — uno stesso spazio di memoria che può contenere tipi diversi. Non puoi metterci oggetti C++ con costruttori (`std::vector` diretto, `unique_ptr`) — solo puntatori.

I token senza valore (parole chiave, punteggiatura) non hanno `<tipo>`:
```yacc
%token T_INT T_FLOAT T_ASSIGN T_PLUS T_MINUS T_SEMICOLON T_ERROR
%token T_IF T_LPAREN T_RPAREN T_LBRACE T_RBRACE
%token T_EQ T_NE T_LT T_GT T_LE T_GE
```

I non-terminali dichiarano il loro tipo con `%type`:
```yacc
%type <nodo> espressione istruzione condizione
%type <list> lista_istruzioni blocco
```

### Precedenze

```yacc
%left T_PLUS T_MINUS
%left T_EQ T_NE T_LT T_GT T_LE T_GE
```

Quando hai operatori ambigui tipo `a + b == c`, Bison non sa se fare `(a+b)==c` o `a+(b==c)`. Le direttive `%left`/`%right` risolvono i conflitti **shift/reduce** — dichiarate prima hanno priorità minore, dichiarate dopo hanno priorità maggiore. `%left` significa associatività a sinistra: `a + b + c` diventa `(a + b) + c`.

### La sintassi delle regole grammaticali

```
nome_regola:
    sequenza_di_simboli  { azione C++ }
  | alternativa          { azione C++ }
  | /* vuoto */
  ;
```

- `:` significa *"è definito come"*
- `|` significa *"oppure"*
- `;` chiude la regola
- `{ }` è codice C++ eseguito quando quella sequenza viene riconosciuta

### I `$` nelle azioni

```yacc
T_INT T_ID T_ASSIGN espressione T_SEMICOLON
  $1   $2    $3        $4          $5
```

- `$1`, `$2`, ... → i simboli del corpo della regola, contando tutti anche quelli senza valore
- `$$` → il valore che questa regola produce verso la regola padre
- Il valore di `$2` è quello che il lexer ha messo in `yylval.str`

---

## 3. Analisi semantica — la symbol table

La grammatica da sola non può sapere se `x` è stata dichiarata o inizializzata — dipende dal contesto. Questo è il compito dell'analisi semantica, che vive nelle azioni `{ }` e nella symbol table definita in `driver.h`:

```cpp
enum TipoVar { TIPO_INT, TIPO_FLOAT };

struct Simbolo {
    TipoVar tipo;
    bool    inizializzato;
    float   valore;
};
```

I controlli che vengono fatti:

| Situazione | Errore generato |
|---|---|
| `int x; int x;` | Variabile già dichiarata |
| `x = 5;` senza `int x;` prima | Variabile non dichiarata |
| `int x; y = x + 1;` | Variabile usata prima di essere inizializzata |

---

## 4. Location Tracking

Con `%locations` nel parser e `yylineno` nel lexer, ogni errore riporta riga e colonna:

```cpp
void yyerror(Driver& drv, const char *s) {
    std::cerr << yylloc.first_line << ":" << yylloc.first_column
              << ": Errore: " << s << std::endl;
}
```

Nel lexer si aggiorna la posizione ad ogni token con `YY_USER_ACTION`:

```lex
#define YY_USER_ACTION \
    yylloc.first_line   = yylloc.last_line   = yylineno; \
    yylloc.first_column = yylloc.last_column + 1; \
    yylloc.last_column  = yylloc.first_column + yyleng - 1;
```

---

## 5. Il Driver

Il driver è una classe C++ che raccoglie tutto il contesto di compilazione, evitando variabili globali:

```cpp
// driver.h
class Driver {
public:
    std::map<std::string, Simbolo> tabella;
    Programma programma;
    int parse();
};
```

Con `%param { Driver& drv }` nel parser, Bison modifica automaticamente le firme di tutto:

| Funzione | Senza driver | Con driver |
|---|---|---|
| `yyparse` | `int yyparse()` | `int yyparse(Driver& drv)` |
| `yylex` | `int yylex()` | `int yylex(Driver& drv)` |
| `yyerror` | `void yyerror(const char*)` | `void yyerror(Driver&, const char*)` |

Nel `main` istanzi il driver e lo passi:

```cpp
int main(int argc, char* argv[]) {
    Driver drv;
    if (argc > 1) {
        yyin = fopen(argv[1], "r");  // legge da file
    }
    if (yyparse(drv) == 0)
        drv.programma.print();
    return 0;
}
```

---

## 6. AST — Abstract Syntax Tree

### Interprete vs compilatore

| | Interprete (prima) | Compilatore (adesso) |
|---|---|---|
| Cosa fa il parser | Esegue direttamente nelle azioni `{ }` | Costruisce nodi dell'albero |
| Risultato | Stampa `[PARSER] x = 10` durante il parsing | Costruisce l'albero, lo visita alla fine |
| Flessibilità | Bassa — non puoi rivisitare il codice | Alta — puoi fare più passate sull'AST |

### La gerarchia delle classi

```
Nodo  (classe base virtuale pura)
├── NodoIntero       int valore
├── NodoFloat        float valore
├── NodoID           string nome
├── NodoBinop        char op, Nodo* lhs, Nodo* rhs
├── NodoUnario       Nodo* figlio
├── NodoDichiara     string tipo, string nome, Nodo* valore
├── NodoAssegna      string nome, Nodo* valore
└── NodoIf           Nodo* condizione, vector<Nodo*> blocco
```

`Nodo` ha il distruttore virtuale — fondamentale perché permette di fare `delete` su un `Nodo*` e chiamare il distruttore corretto della classe figlia. Senza di esso si ha undefined behavior.

### Puntatori grezzi e gestione della memoria

Si usano puntatori grezzi (`Nodo*`) invece di `unique_ptr` perché l'`%union` di Bison è una union C e non supporta tipi con costruttori. Ogni nodo si occupa di liberare i suoi figli nel distruttore:

```cpp
struct NodoBinop : Nodo {
    char  op;
    Nodo *lhs, *rhs;
    NodoBinop(char o, Nodo* l, Nodo* r) : op(o), lhs(l), rhs(r) {}
    ~NodoBinop() { delete lhs; delete rhs; }  // ← libera i figli
};
```

La proprietà scende dall'alto verso il basso — chi crea un nodo ne è proprietario, chi lo riceve come figlio lo distrugge nel suo distruttore.

### `std::move` e il vettore del blocco

`NodoIf` riceve un `std::vector<Nodo*>*` dal parser e ne prende il contenuto con `std::move`:

```cpp
NodoIf(Nodo* c, std::vector<Nodo*>* b)
    : condizione(c), blocco(std::move(*b)) { delete b; }
```

`std::move` trasferisce il contenuto interno del vettore puntato da `b` dentro `blocco` **senza copiarlo** — è un'operazione O(1) indipendentemente da quante istruzioni ci sono nel blocco. Dopo il move, `*b` è vuoto, quindi `delete b` libera solo il contenitore ormai vuoto.

### Come viene costruito l'albero nel parser

Ogni regola restituisce un `Nodo*` tramite `$$`:

```yacc
espressione:
    T_INT_NUMBER     { $$ = new NodoIntero($1); }
    | T_FLOAT_NUMBER { $$ = new NodoFloat($1); }
    | T_ID           { $$ = new NodoID($1); }
    | espressione T_PLUS espressione { $$ = new NodoBinop('+', $1, $3); }
    | T_MINUS espressione            { $$ = new NodoUnario($2); }
    ;
```

I nodi figlio (`$1`, `$3`) vengono passati al nodo padre che ne diventa proprietario. L'albero cresce dal basso verso l'alto — le foglie vengono create per prime, poi i nodi intermedi, poi la radice.

### `lista_istruzioni` e l'ordine di inserimento

```yacc
lista_istruzioni:
    istruzione lista_istruzioni
    {
        $2->insert($2->begin(), $1);  // inserisce in testa
        $$ = $2;
    }
    | /* vuoto */
    { $$ = new std::vector<Nodo*>(); }
    ;
```

La ricorsione è a destra — il parser costruisce prima la coda e poi inserisce la testa. `insert($2->begin(), $1)` mette l'istruzione corrente all'inizio del vettore già costruito, mantenendo l'ordine corretto.

### La visita — `print`

Ogni nodo implementa `print(int indent)` che stampa sé stesso e poi chiama ricorsivamente `print` sui figli con indentazione aumentata:

```cpp
void NodoBinop::print(int i) const {
    indent(i); std::cout << "Binop: " << op << "\n";
    lhs->print(i + 1);   // ← visita ricorsiva
    rhs->print(i + 1);
}
```

Per input `int x = 5 + y;` l'output è:

```
=== AST ===
Dichiara: int x
  Binop: +
    Intero: 5
    ID: y
```

Questo pattern — classe base virtuale con metodo `visit`/`print` implementato da ogni figlia — si chiama **Visitor pattern** ed è il modo standard per attraversare un AST.

---

## 7. Flusso completo — esempio con `int x = 5 + 3;`

```
"int"  → Flex → T_INT
"x"    → Flex → T_ID ("x")
"="    → Flex → T_ASSIGN
"5"    → Flex → strtoll → ok → T_INT_NUMBER (5)
"+"    → Flex → T_PLUS
"3"    → Flex → strtoll → ok → T_INT_NUMBER (3)
";"    → Flex → T_SEMICOLON

Bison riduce:
  T_INT_NUMBER(5) → espressione → NodoIntero(5)
  T_INT_NUMBER(3) → espressione → NodoIntero(3)
  espressione + espressione → NodoBinop('+', NodoIntero(5), NodoIntero(3))
  T_INT "x" = espressione ; → NodoDichiara("int","x", NodoBinop(...))

Alla fine:
  drv.programma.print() →
    Dichiara: int x
      Binop: +
        Intero: 5
        Intero: 3
```

---

## 8. Le funzioni di supporto

| Funzione | Chi la crea | Cosa fa |
|---|---|---|
| `yylex(Driver&)` | Flex | Legge il prossimo token e lo passa a Bison |
| `yyparse(Driver&)` | Bison | Il motore principale, chiamato nel `main()` |
| `yyerror(Driver&, msg)` | Tu | Chiamata automaticamente quando qualcosa non va |
| `print(int indent)` | Tu (ast.cpp) | Visita ricorsiva dell'AST con indentazione |