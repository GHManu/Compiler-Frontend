#pragma once
#include <map>
#include <string>


// ── Symbol table ──────────────────────────────────────────
// ── Tipi condivisi tra driver, parser e lexer ──
enum TipoVar { TIPO_INT, TIPO_FLOAT };

struct Simbolo {
    TipoVar tipo;
    bool    inizializzato;
    float   valore; // Memorizziamo il valore (usiamo float per semplicità tra i due tipi)
};

//std::map<std::string, Simbolo> tabella;
// ──────────────────────────────────────────────────────────

class Driver {
public:
    std::map<std::string, Simbolo> tabella;
    int parse();
};