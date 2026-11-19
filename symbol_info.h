#ifndef SYMBOL_INFO_H
#define SYMBOL_INFO_H

#include<bits/stdc++.h>
using namespace std;

extern ofstream outlog;

// Forward declaration
class ASTNode;

class symbol_info
{
private:
    string symbol_name;
    string symbol_type;
    string symbol_size;
    string symbol_category;
    vector<string> param_types;
    vector<string> param_names;
    string data_type;
    bool is_array_flag;
    bool is_function_flag;
    vector<string> arg_types;
    ASTNode* ast_node;   // for Lab 4: hold AST node

public:

    symbol_info(string n, string t)
    {
        symbol_name = n;
        symbol_type = t;
        symbol_size = "";
        symbol_category = "VARIABLE";
        data_type = t;
        is_array_flag = false;
        is_function_flag = false;
        ast_node = nullptr;
    }

    string getnameofsymbol() { return symbol_name; }
    void setnameofsymbol(string n) { symbol_name = n; }

    string gettypeofsymbol() { return symbol_type; }
    void settypeofsymbol(string t) { symbol_type = t; }

    string getsizeofsymbol() { return symbol_size; }

    void set_array_size(int size)
    {
        symbol_size = to_string(size);
        symbol_category = "ARRAY";
        is_array_flag = true;
    }

    void set_symbol_category(string category)
    {
        symbol_category = category;
        if (category == "ARRAY") is_array_flag = true;
        if (category == "FUNCTION") is_function_flag = true;
    }

    string get_symbol_category() { return symbol_category; }

    void add_param_type(string type) { param_types.push_back(type); }
    void add_param_name(string name) { param_names.push_back(name); }

    vector<string> get_param_types() { return param_types; }
    vector<string> get_param_names() { return param_names; }
    int get_param_count() { return (int)param_types.size(); }

    void set_data_type(string t) { data_type = t; }
    string get_data_type() { return data_type; }

    void set_is_array(bool v) { is_array_flag = v; if(v) symbol_category = "ARRAY"; }
    bool is_array() { return is_array_flag || symbol_category == "ARRAY"; }

    void set_is_function(bool v) { is_function_flag = v; if(v) symbol_category = "FUNCTION"; }
    bool is_function() { return is_function_flag || symbol_category == "FUNCTION"; }

    void add_arg_type(string t) { arg_types.push_back(t); }
    void set_arg_types(vector<string> v) { arg_types = v; }
    vector<string> get_arg_types() { return arg_types; }

    // Lab 4: AST node support
    void set_ast_node(ASTNode* node) { ast_node = node; }
    ASTNode* get_ast_node() { return ast_node; }
};

#endif
