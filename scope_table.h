#ifndef SCOPE_TABLE_H
#define SCOPE_TABLE_H

#include "symbol_info.h"

class scope_table
{
private:
    int bucket_count;
    int unique_id;
    scope_table *parent_scope;
    vector<list<symbol_info *>> table;

    int hash_function(string name)
    {
        unsigned long hash_val = 0;
        for (size_t i = 0; i < name.size(); i++)
        {
            hash_val = hash_val * 131 + (unsigned char)name[i];
        }
        return (int)(hash_val % (unsigned long)bucket_count);
    }

public:
    scope_table()
    {
        bucket_count = 0;
        unique_id = 0;
        parent_scope = NULL;
    }

    scope_table(int bucket_count, int unique_id, scope_table *parent_scope)
    {
        this->bucket_count = bucket_count;
        this->unique_id = unique_id;
        this->parent_scope = parent_scope;
        table.resize(bucket_count);
    }

    scope_table *get_parent_scope() { return parent_scope; }
    int get_unique_id() { return unique_id; }

    symbol_info *lookup_in_scope(symbol_info *symbol)
    {
        return lookup_in_scope(symbol->getnameofsymbol());
    }

    symbol_info *lookup_in_scope(string name)
    {
        int idx = hash_function(name);
        for (list<symbol_info *>::iterator it = table[idx].begin(); it != table[idx].end(); it++)
        {
            if ((*it)->getnameofsymbol() == name)
                return *it;
        }
        return NULL;
    }

    bool insert_in_scope(symbol_info *symbol)
    {
        if (lookup_in_scope(symbol->getnameofsymbol()) != NULL)
            return false;

        int idx = hash_function(symbol->getnameofsymbol());
        table[idx].push_back(symbol);
        return true;
    }

    bool delete_from_scope(symbol_info *symbol)
    {
        int idx = hash_function(symbol->getnameofsymbol());
        for (list<symbol_info *>::iterator it = table[idx].begin(); it != table[idx].end(); it++)
        {
            if ((*it)->getnameofsymbol() == symbol->getnameofsymbol())
            {
                delete (*it);
                table[idx].erase(it);
                return true;
            }
        }
        return false;
    }

    void print_scope_table(ofstream &outlog)
    {
        outlog << "ScopeTable # " << unique_id << endl;

        for (int i = 0; i < bucket_count; i++)
        {
            if (table[i].empty())
                continue;

            outlog << i << " --> " << endl;
            for (list<symbol_info *>::iterator it = table[i].begin(); it != table[i].end(); it++)
            {
                symbol_info *s = *it;
                outlog << "< " << s->getnameofsymbol() << " : ID >" << endl;

                if (s->get_symbol_category() == "FUNCTION")
                {
                    outlog << "Function Definition" << endl;
                    outlog << "Return Type: " << s->gettypeofsymbol() << endl;
                    outlog << "Number of Parameters: " << s->get_param_count() << endl;
                    outlog << "Parameter Details: ";
                    vector<string> ptypes = s->get_param_types();
                    vector<string> pnames = s->get_param_names();
                    for (size_t p = 0; p < ptypes.size(); p++)
                    {
                        outlog << ptypes[p];
                        if (p < pnames.size())
                            outlog << " " << pnames[p];
                        if (p + 1 < ptypes.size())
                            outlog << ", ";
                    }
                    outlog << endl;
                }
                else
                {
                    outlog << "Variable" << endl;
                    outlog << "Type: " << s->gettypeofsymbol() << endl;
                    if (s->get_symbol_category() == "ARRAY")
                        outlog << "Size: " << s->getsizeofsymbol() << endl;
                }
            }
        }
        outlog << endl;
    }

    ~scope_table()
    {
        for (int i = 0; i < bucket_count; i++)
        {
            for (list<symbol_info *>::iterator it = table[i].begin(); it != table[i].end(); it++)
            {
                delete (*it);
            }
            table[i].clear();
        }
        table.clear();
    }
};

#endif
