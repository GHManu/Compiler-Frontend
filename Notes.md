Ecco una versione più chiara e organizzata:

---

# Flex & Bison — Come funziona

## Il flusso generale

```
Testo sorgente → [Lexer/Flex] → Token → [Parser/Bison] → Analisi semantica
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
| `[0-9]+` | Sequenza di cifre | Converte con `atoi`, salva in `yylval.num`, restituisce `T_INT_NUMBER` |
| `[0-9]+"."[0-9]*` | Numero decimale | Converte con `atof`, salva in `yylval.fnum`, restituisce `T_FLOAT_NUMBER` |
| `[a-zA-Z_][a-zA-Z0-9_]*` | Nome variabile | Duplica la stringa con `strdup`, salva in `yylval.str`, restituisce `T_ID` |
| `[ \t\n]` | Spazi/tab/invio | Ignora |
| `.` | Qualsiasi altro carattere | Errore |

### Perché `strtoll`/`strtod` invece di `atoi`/`atof`?

`atoi` e `atof` non controllano nulla — convertono e basta. Se scrivi `999999999999` nel sorgente, `atoi` ti dà silenziosamente un risultato troncato. Quindi il range check va fatto **qui nel lexer**, prima che il valore arrivi al parser:

```c
[0-9]+ {
    long long val = strtoll(yytext, NULL, 10);
    if (val > 2147483647LL || val < -2147483648LL) {
        yyerror("Overflow: intero fuori range");
        return T_ERROR;
    }
    yylval.num = (int)val;
    return T_INT_NUMBER;
}
```

L'idea è usare un tipo più grande (`long long`, `double`) per leggere il valore grezzo, controllare se sta nel range del tipo target, e solo allora fare il cast.

> **Nota:** il segno negativo non serve qui perché i letterali nel sorgente sono sempre positivi — il meno è gestito dalla regola `T_MINUS espressione` nel parser.

---

## 2. Analizzatore Sintattico — `parser.y`

Il parser riceve i token dal lexer e verifica che seguano le regole grammaticali del linguaggio.

### `%union` e `%token`

```yacc
%union {
    int   num;    // per T_INT_NUMBER
    float fnum;   // per T_FLOAT_NUMBER
    char *str;    // per T_ID
}
```

`%union` è una `union` C — uno stesso spazio di memoria che può contenere tipi diversi. Ogni token dichiara quale campo usa:

```yacc
%token <num>  T_INT_NUMBER
%token <fnum> T_FLOAT_NUMBER
%token <str>  T_ID
```

I token senza valore (parole chiave, punteggiatura) non hanno `<tipo>`:
```yacc
%token T_INT T_FLOAT T_ASSIGN T_PLUS T_SEMICOLON T_MINUS T_ERROR
```

---

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

---

### Le regole, una per una

**`programma`** — il punto di partenza, non fa nient'altro che aspettarsi una lista di istruzioni:
```yacc
programma:
    lista_istruzioni
    ;
```

**`lista_istruzioni`** — ricorsione a destra, il modo bison per dire "zero o più":
```yacc
lista_istruzioni:
    istruzione lista_istruzioni
    | /* vuoto */
    ;
```

**`istruzione`** — le forme valide di un'istruzione:
```yacc
istruzione:
    T_INT T_ID T_SEMICOLON                         // int x;
    | T_INT T_ID T_ASSIGN espressione T_SEMICOLON  // int x = ...;
    | T_FLOAT T_ID T_SEMICOLON                     // float x;
    | T_FLOAT T_ID T_ASSIGN espressione T_SEMICOLON // float x = ...;
    | T_ID T_ASSIGN espressione T_SEMICOLON        // x = ...;
    ;
```

**`espressione`** — ricorsiva, permette `1 + 2 + 3` senza scriverlo esplicitamente:
```yacc
espressione:
    T_INT_NUMBER
    | T_FLOAT_NUMBER
    | T_ID
    | espressione T_PLUS espressione
    | T_MINUS espressione
    ;
```

### I `$` nelle azioni

Dentro le azioni `{ }` puoi riferire i simboli della regola per posizione:

```yacc
T_INT T_ID T_ASSIGN espressione T_SEMICOLON
  $1   $2    $3        $4          $5
```

- `$1` = `T_INT`
- `$2` = `T_ID` ← il nome della variabile, quello che il lexer ha messo in `yylval.str`
- `$$` = il valore che questa regola produce verso la regola padre

---

## 3. Analisi semantica — la symbol table

La grammatica da sola non può sapere se `x` è stata dichiarata o inizializzata — dipende dal contesto. Questo è il compito dell'**analisi semantica**, che vive nelle azioni `{ }` e nella symbol table:

```cpp
enum TipoVar { TIPO_INT, TIPO_FLOAT };

struct Simbolo {
    TipoVar tipo;
    bool    inizializzato;
};

std::map<std::string, Simbolo> tabella;
```

I controlli che vengono fatti:

| Situazione | Errore generato |
|---|---|
| `int x; int x;` | Variabile già dichiarata |
| `x = 5;` senza `int x;` prima | Variabile non dichiarata |
| `int x; y = x + 1;` | Variabile usata prima di essere inizializzata |

---

## 4. Flusso completo — esempio con `int counter = 5;`

```
"int"     → Flex → T_INT
"counter" → Flex → T_ID ("counter")
"="       → Flex → T_ASSIGN
"5"       → Flex → strtoll → range check ok → T_INT_NUMBER (5)
";"       → Flex → T_SEMICOLON

Bison vede: T_INT T_ID T_ASSIGN T_INT_NUMBER T_SEMICOLON
            ↓
Corrisponde a: T_INT T_ID T_ASSIGN espressione T_SEMICOLON
            ↓
Esegue azione: controlla tabella → non esiste → inserisce {TIPO_INT, true}
```

---

## 5. Le funzioni di supporto

| Funzione | Chi la crea | Cosa fa |
|---|---|---|
| `yylex()` | Flex | Legge il prossimo token e lo passa a Bison |
| `yyparse()` | Bison | Il motore principale, chiamato nel `main()` |
| `yyerror(msg)` | Tu | Chiamata automaticamente quando qualcosa non va |


## Precedenze
```%left T_PLUS T_MINUS
%left T_EQ T_NE T_LT T_GT T_LE T_GE
```
Quando aggiungi operatori come == o +, Bison potrebbe darti dei conflitti "Shift/Reduce" (non sa cosa calcolare prima).

## Interpretazione
Aggiungo valore per fare si che memorizzi il risultato dell'operazione che voglio fare
struct Simbolo {
    TipoVar tipo;
    bool    inizializzato;
    float   valore; // Memorizziamo il valore (usiamo float per semplicità tra i due tipi)
};
per le condizioni:
%union {
    int   num;
    float fnum;
    char *str;
    bool  boolean; // Aggiunto per il risultato delle condizioni
}


per fare si che i blocchi possano restituire un valore:
%type <fnum> espressione
%type <boolean> condizione

Tabella dei Simboli: Ora ha un campo float valore. Anche se hai int, memorizzarli come float in questa fase è più semplice per gestire i calcoli misti.

$$ = ...: In ogni regola di espressione e condizione, abbiamo aggiunto l'operazione matematica o logica reale.

Output: Ad ogni assegnamento o valutazione dell'IF, il parser stamperà a console il valore calcolato.