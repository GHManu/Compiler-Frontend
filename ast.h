#pragma once
#include <string>
#include <vector>

struct Nodo {
    virtual ~Nodo() = default;
    virtual void print(int indent = 0) const = 0;
};

// ── Foglie ─────────────────────────────────────
struct NodoIntero : Nodo {
    int valore;
    NodoIntero(int v) : valore(v) {}
    void print(int indent) const override;
};

struct NodoFloat : Nodo {
    float valore;
    NodoFloat(float v) : valore(v) {}
    void print(int indent) const override;
};

struct NodoID : Nodo {
    std::string nome;
    NodoID(std::string n) : nome(std::move(n)) {}
    void print(int indent) const override;
};

// ── Operazioni ─────────────────────────────────
struct NodoBinop : Nodo {
    char  op;
    Nodo *lhs, *rhs;    // ← grezzi, non unique_ptr
    NodoBinop(char o, Nodo* l, Nodo* r) : op(o), lhs(l), rhs(r) {}
    ~NodoBinop() { delete lhs; delete rhs; }
    void print(int indent) const override;
};

struct NodoUnario : Nodo {
    Nodo* figlio;       // ← grezzo
    NodoUnario(Nodo* f) : figlio(f) {}
    ~NodoUnario() { delete figlio; }
    void print(int indent) const override;
};

// ── Istruzioni ─────────────────────────────────
struct NodoDichiara : Nodo {
    std::string tipo;
    std::string nome;
    Nodo* valore;       // ← grezzo, può essere nullptr
    NodoDichiara(std::string t, std::string n, Nodo* v)
        : tipo(std::move(t)), nome(std::move(n)), valore(v) {}
    ~NodoDichiara() { delete valore; }
    void print(int indent) const override;
};

struct NodoAssegna : Nodo {
    std::string nome;
    Nodo* valore;       // ← grezzo
    NodoAssegna(std::string n, Nodo* v)
        : nome(std::move(n)), valore(v) {}
    ~NodoAssegna() { delete valore; }
    void print(int indent) const override;
};

struct NodoIf : Nodo {
    Nodo* condizione;
    std::vector<Nodo*> blocco;
    NodoIf(Nodo* c, std::vector<Nodo*>* b)
        : condizione(c), blocco(std::move(*b)) { delete b; }
    ~NodoIf() { delete condizione; for (auto* n : blocco) delete n; }
    void print(int indent) const override;
};

// ── Radice ─────────────────────────────────────
struct Programma {
    std::vector<Nodo*> istruzioni;
    ~Programma() { for (auto* n : istruzioni) delete n; }
    void print() const;
};