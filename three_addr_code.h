#ifndef THREE_ADDR_CODE_H
#define THREE_ADDR_CODE_H

#include "ast.h"
#include <fstream>
#include <string>
#include <map>

using namespace std;

class ThreeAddrCodeGenerator {
private:
    ProgramNode* ast_root;
    ofstream& outcode;
    map<string, string> symbol_to_temp;
    int temp_count;
    int label_count;

public:
    ThreeAddrCodeGenerator(ProgramNode* root, ofstream& out)
        : ast_root(root), outcode(out), temp_count(0), label_count(0) {}

    void generate() {
        // Write header
        outcode << "; Three Address Code generated from AST" << endl;
        outcode << "; =====================================" << endl << endl;

        if (ast_root) {
            ast_root->generate_code(outcode, symbol_to_temp, temp_count, label_count);
        }

        // Write footer
        outcode << endl << "; End of three address code" << endl;
    }
};

#endif // THREE_ADDR_CODE_H
