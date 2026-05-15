#include "ast.h"
#include <iostream>

// helper per l'indentazione
static void indent(int n) {
    for (int i = 0; i < n; i++) std::cout << "  ";
}

void NodoIntero::print(int i) const {
    indent(i); std::cout << "Intero: " << valore << "\n";
}

void NodoFloat::print(int i) const {
    indent(i); std::cout << "Float: " << valore << "\n";
}

void NodoID::print(int i) const {
    indent(i); std::cout << "ID: " << nome << "\n";
}

void NodoBinop::print(int i) const {
    indent(i); std::cout << "Binop: " << op << "\n";
    lhs->print(i + 1);
    rhs->print(i + 1);
}

void NodoUnario::print(int i) const {
    indent(i); std::cout << "Unario: -\n";
    figlio->print(i + 1);
}

void NodoDichiara::print(int i) const {
    indent(i); std::cout << "Dichiara: " << tipo << " " << nome << "\n";
    if (valore) valore->print(i + 1);
}

void NodoAssegna::print(int i) const {
    indent(i); std::cout << "Assegna: " << nome << "\n";
    valore->print(i + 1);
}

void NodoIf::print(int i) const {
    indent(i); std::cout << "If:\n";
    indent(i + 1); std::cout << "condizione:\n";
    condizione->print(i + 2);
    indent(i + 1); std::cout << "blocco:\n";
    for (const auto& istr : blocco)
        istr->print(i + 2);
}

void Programma::print() const {
    std::cout << "=== AST ===\n";
    for (const auto& istr : istruzioni)
        istr->print(0);
}
