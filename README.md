# !!!!!!! WORKING IN PROGRESS !!!!!!!
# Compiler-Frontend
## **Descrizione del Progetto: Interprete Lex/Yacc**

Il progetto consiste nello sviluppo di un **sistema di analisi e interpretazione** di un linguaggio di programmazione semplificato. Il sistema non genera codice macchina (compilatore), ma esegue direttamente le istruzioni man mano che vengono analizzate (**interprete**).

> Ho realizzato un **interprete interattivo** che legge il codice sorgente, ne valida la sintassi e calcola i risultati in tempo reale, mantenendo traccia dello stato delle variabili attraverso una tabella dei simboli integrata nel parser.

### **Componenti del sistema:**

* **Analizzatore Lessicale (Flex):** Si occupa di scansionare il testo in input per identificare i "token" (parole chiave come `if`, `int`, operatori, numeri e identificatori), gestendo anche i commenti e controllando i range numerici (overflow).
* **Analizzatore Sintattico (Bison/Yacc):** Definisce la grammatica del linguaggio. Verifica che la sequenza dei token sia corretta e costruisce la struttura logica del programma.
* **Tabella dei Simboli (`std::map`):** Una struttura dati che memorizza il nome, il tipo (`int` o `float`) e il valore delle variabili dichiarate, permettendo di gestire lo stato del programma durante l'esecuzione.

### **Funzionalità implementate:**

* **Dichiarazione e Inizializzazione:** Gestione di tipi `int` e `float` con controllo sulle ridefinizioni.
* **Espressioni Matematiche:** Valutazione di somme, sottrazioni e negazioni, con supporto alla precedenza degli operatori.
* **Strutture di Controllo:** Implementazione del costrutto `if` con valutazione dinamica delle condizioni booleane (`==`, `!=`, `<`, `>`, ecc.).
* **Semantic Check:** Controllo degli errori a runtime, come l'utilizzo di variabili non dichiarate o non inizializzate.

---

## How To Run
1. Genera i file C++ da Bison:
    bison -d parser.y  (Crea parser.tab.c e parser.tab.h)

2. Genera i file C++ da Flex:
    flex lexer.l (Crea lex.yy.c)

3. Compila tutto insieme:
    g++ lex.yy.c parser.tab.c ast.cpp -o compiler

4. Esegui: 
    ./compiler 
