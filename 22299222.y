%{

#include"symbol_info.h"
#include"symbol_table.h"
#include"ast.h"
#include"three_addr_code.h"

#define YYSTYPE symbol_info*

int yyparse(void);
int yylex(void);

extern FILE *yyin;

ofstream outlog;
ofstream outerr;
ofstream outcode;
void yyerror(const char *s);
int line_num = 1;
int error_count = 0;

symbol_table *symtab;

vector<pair<string,int>> decl_buffer;

bool reuse_scope_for_func_body = false;

symbol_info *current_function_symbol = NULL;

ProgramNode *ast_root = NULL;

// helper to report semantic error to both log and error file
void semantic_error(const string &msg)
{
	outlog << "At line no: " << line_num << " " << msg << endl << endl;
	outerr << "At line no: " << line_num << " " << msg << endl << endl;
	error_count++;
}

// type promotion for arithmetic: int + float -> float
string result_type(string t1, string t2)
{
	if (t1 == "error" || t2 == "error" || t1 == "undeclared" || t2 == "undeclared")
		return "error";
	if (t1 == "void" || t2 == "void")
		return "error";
	if (t1 == "float" || t2 == "float")
		return "float";
	return "int";
}

%}

%token ID IF WHILE ADDOP COMMA FOR DO INT FLOAT CONTINUE ELSE BREAK CHAR DOUBLE CASE VOID SWITCH DEFAULT GOTO RETURN PRINTLN MULOP INCOP DECOP RELOP ASSIGNOP LOGICOP NOT LPAREN RPAREN LCURL RCURL LTHIRD RTHIRD COLON SEMICOLON CONST_INT CONST_FLOAT
%nonassoc LOWER_THAN_ELSE
%nonassoc ELSE

%%

start : program
	{
		outlog<<"At line no: "<<line_num<<" start : program "<<endl<<endl;
		ast_root = (ProgramNode*)$1->get_ast_node();
		if (ast_root == NULL) {
			ast_root = new ProgramNode();
		}
	}
	;

program : program unit
	{
		outlog<<"At line no: "<<line_num<<" program : program unit "<<endl<<endl;
		outlog<<$1->getnameofsymbol()+"\n"+$2->getnameofsymbol()<<endl<<endl;
		
		$$ = new symbol_info($1->getnameofsymbol()+"\n"+$2->getnameofsymbol(),"program");
		ProgramNode* pnode = (ProgramNode*)$1->get_ast_node();
		if (pnode == NULL) pnode = new ProgramNode();
		if ($2->get_ast_node()) pnode->add_unit($2->get_ast_node());
		$$->set_ast_node(pnode);
	}
	| unit
	{
		outlog<<"At line no: "<<line_num<<" program : unit "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"program");
		ProgramNode* pnode = new ProgramNode();
		if ($1->get_ast_node()) pnode->add_unit($1->get_ast_node());
		$$->set_ast_node(pnode);
	}
	;

unit : variable_decl
	{
		outlog<<"At line no: "<<line_num<<" unit : variable_decl "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"unit");
		$$->set_ast_node($1->get_ast_node());
	}
	| func_definition
	{
		outlog<<"At line no: "<<line_num<<" unit : func_definition "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"unit");
		$$->set_ast_node($1->get_ast_node());
	}
	;

func_definition : type_specifier ID
		{
			symbol_info *fsym = new symbol_info($2->getnameofsymbol(), $1->getnameofsymbol());
			fsym->set_symbol_category("FUNCTION");
			fsym->set_data_type($1->getnameofsymbol());
			if (!symtab->insert(fsym))
			{
				semantic_error("Multiple declaration of function " + $2->getnameofsymbol());
				delete fsym;
				// still keep a dummy so parameters can attach
				fsym = new symbol_info($2->getnameofsymbol(), $1->getnameofsymbol());
				fsym->set_symbol_category("FUNCTION");
				fsym->set_data_type($1->getnameofsymbol());
			}
			current_function_symbol = fsym;

			symtab->enter_scope();
			reuse_scope_for_func_body = true;
		}
		LPAREN func_param_clause RPAREN compound_statement
		{
			if ($5->gettypeofsymbol() == "with_params")
			{
				outlog<<"At line no: "<<line_num<<" func_definition : type_specifier ID LPAREN param_list RPAREN compound_statement "<<endl<<endl;
				outlog<<$1->getnameofsymbol()<<" "<<$2->getnameofsymbol()<<"("<<$5->getnameofsymbol()<<")\n"<<$7->getnameofsymbol()<<endl<<endl;

				$$ = new symbol_info($1->getnameofsymbol()+" "+$2->getnameofsymbol()+"("+$5->getnameofsymbol()+")\n"+$7->getnameofsymbol(),"func_definition");
			}
			else
			{
				outlog<<"At line no: "<<line_num<<" func_definition : type_specifier ID LPAREN RPAREN compound_statement "<<endl<<endl;
				outlog<<$1->getnameofsymbol()<<" "<<$2->getnameofsymbol()<<"()\n"<<$7->getnameofsymbol()<<endl<<endl;

				$$ = new symbol_info($1->getnameofsymbol()+" "+$2->getnameofsymbol()+"()\n"+$7->getnameofsymbol(),"func_definition");
			}
			// Lab 4: build FuncDeclNode
			FuncDeclNode* fnode = new FuncDeclNode($1->getnameofsymbol(), $2->getnameofsymbol());
			if (current_function_symbol) {
				vector<string> pts = current_function_symbol->get_param_types();
				vector<string> pns = current_function_symbol->get_param_names();
				for (size_t i = 0; i < pts.size(); i++) {
					fnode->add_param(pts[i], pns[i]);
				}
			}
			BlockNode* body = (BlockNode*)$7->get_ast_node();
			if (body) fnode->set_body(body);
			$$->set_ast_node(fnode);
			current_function_symbol = NULL;
		}
 		;

func_param_clause : param_list
		{
			$$ = new symbol_info($1->getnameofsymbol(), "with_params");
		}
		| /* empty */
		{
			$$ = new symbol_info("", "no_params");
		}
		;

param_list : param_list COMMA type_specifier ID
	{
		outlog<<"At line no: "<<line_num<<" param_list : param_list COMMA type_specifier ID "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<","<<$3->getnameofsymbol()<<" "<<$4->getnameofsymbol()<<endl<<endl;

		// insert parameter into current (function) scope
		symbol_info *psym = new symbol_info($4->getnameofsymbol(), $3->getnameofsymbol());
		psym->set_data_type($3->getnameofsymbol());
		if (!symtab->insert(psym))
		{
			string fname = current_function_symbol ? current_function_symbol->getnameofsymbol() : "";
			semantic_error("Multiple declaration of variable " + $4->getnameofsymbol() + " in parameter of " + fname);
			delete psym;
		}
		if (current_function_symbol)
		{
			current_function_symbol->add_param_type($3->getnameofsymbol());
			current_function_symbol->add_param_name($4->getnameofsymbol());
		}

		$$ = new symbol_info($1->getnameofsymbol()+","+$3->getnameofsymbol()+" "+$4->getnameofsymbol(),"param_list");
	}
	| type_specifier ID
	{
		outlog<<"At line no: "<<line_num<<" param_list : type_specifier ID "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<" "<<$2->getnameofsymbol()<<endl<<endl;

		symbol_info *psym = new symbol_info($2->getnameofsymbol(), $1->getnameofsymbol());
		psym->set_data_type($1->getnameofsymbol());
		if (!symtab->insert(psym))
		{
			string fname = current_function_symbol ? current_function_symbol->getnameofsymbol() : "";
			semantic_error("Multiple declaration of variable " + $2->getnameofsymbol() + " in parameter of " + fname);
			delete psym;
		}
		if (current_function_symbol)
		{
			current_function_symbol->add_param_type($1->getnameofsymbol());
			current_function_symbol->add_param_name($2->getnameofsymbol());
		}

		$$ = new symbol_info($1->getnameofsymbol()+" "+$2->getnameofsymbol(),"param_list");
	}
	;

compound_statement : LCURL
	{
		if (reuse_scope_for_func_body)
			reuse_scope_for_func_body = false;
		else
			symtab->enter_scope();
	}
	statements RCURL
	{
		outlog<<"At line no: "<<line_num<<" compound_statement : LCURL statements RCURL "<<endl<<endl;
		outlog<<"{\n"+$3->getnameofsymbol()+"\n}"<<endl<<endl;

		symtab->print_all_scopes(outlog);
		symtab->exit_scope();

		$$ = new symbol_info("{\n"+$3->getnameofsymbol()+"\n}","compound_statement");
		// Lab 4: statements already built a BlockNode
		$$->set_ast_node($3->get_ast_node());
	}
	| LCURL
	{
		if (reuse_scope_for_func_body)
			reuse_scope_for_func_body = false;
		else
			symtab->enter_scope();
	}
	RCURL
	{
		outlog<<"At line no: "<<line_num<<" compound_statement : LCURL RCURL "<<endl<<endl;
		outlog<<"{\n}"<<endl<<endl;

		symtab->print_all_scopes(outlog);
		symtab->exit_scope();

		$$ = new symbol_info("{\n}","compound_statement");
		$$->set_ast_node(new BlockNode());
	}
	;

variable_decl : type_specifier declaration_list SEMICOLON
	{
		outlog<<"At line no: "<<line_num<<" variable_decl : type_specifier declaration_list SEMICOLON "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<" "<<$2->getnameofsymbol()<<";"<<endl<<endl;

		string dtype = $1->getnameofsymbol();
		if (dtype == "void")
		{
			semantic_error("variable type can not be void");
		}

		for (size_t i = 0; i < decl_buffer.size(); i++)
		{
			symbol_info *vsym = new symbol_info(decl_buffer[i].first, dtype);
			vsym->set_data_type(dtype);
			if (decl_buffer[i].second != -1)
				vsym->set_array_size(decl_buffer[i].second);

			if (!symtab->insert(vsym))
			{
				semantic_error("Multiple declaration of variable " + decl_buffer[i].first);
				// update type of existing symbol to match later uses in sample
				symbol_info *exist = symtab->lookup_current(decl_buffer[i].first);
				if (exist != NULL && dtype != "void")
				{
					exist->settypeofsymbol(dtype);
					exist->set_data_type(dtype);
					if (decl_buffer[i].second != -1)
						exist->set_array_size(decl_buffer[i].second);
				}
				delete vsym;
			}
		}
		// Lab 4: build DeclNode before clearing buffer
		DeclNode* dnode = new DeclNode(dtype);
		for (size_t i = 0; i < decl_buffer.size(); i++) {
			int asz = (decl_buffer[i].second == -1) ? 0 : decl_buffer[i].second;
			dnode->add_var(decl_buffer[i].first, asz);
		}
		decl_buffer.clear();

		$$ = new symbol_info($1->getnameofsymbol()+" "+$2->getnameofsymbol()+";","variable_decl");
		$$->set_ast_node(dnode);
	}
	;

type_specifier : INT
	{
		outlog<<"At line no: "<<line_num<<" type_specifier : INT "<<endl<<endl;
		outlog<<"int"<<endl<<endl;

		$$ = new symbol_info("int","type");
	}
	| FLOAT
	{
		outlog<<"At line no: "<<line_num<<" type_specifier : FLOAT "<<endl<<endl;
		outlog<<"float"<<endl<<endl;

		$$ = new symbol_info("float","type");
	}
	| VOID
	{
		outlog<<"At line no: "<<line_num<<" type_specifier : VOID "<<endl<<endl;
		outlog<<"void"<<endl<<endl;

		$$ = new symbol_info("void","type");
	}
	| CHAR
	{
		outlog<<"At line no: "<<line_num<<" type_specifier : CHAR "<<endl<<endl;
		outlog<<"char"<<endl<<endl;

		$$ = new symbol_info("char","type");
	}
	;

declaration_list : declaration_list COMMA ID
	{
		outlog<<"At line no: "<<line_num<<" declaration_list : declaration_list COMMA ID "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<","<<$3->getnameofsymbol()<<endl<<endl;

		decl_buffer.push_back(make_pair($3->getnameofsymbol(), -1));

		$$ = new symbol_info($1->getnameofsymbol()+","+$3->getnameofsymbol(),"declaration_list");
	}
	| declaration_list COMMA ID LTHIRD CONST_INT RTHIRD
	{
		outlog<<"At line no: "<<line_num<<" declaration_list : declaration_list COMMA ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<","<<$3->getnameofsymbol()<<"["<<$5->getnameofsymbol()<<"]"<<endl<<endl;

		decl_buffer.push_back(make_pair($3->getnameofsymbol(), stoi($5->getnameofsymbol())));

		$$ = new symbol_info($1->getnameofsymbol()+","+$3->getnameofsymbol()+"["+$5->getnameofsymbol()+"]","declaration_list");
	}
	| ID
	{
		outlog<<"At line no: "<<line_num<<" declaration_list : ID "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		decl_buffer.push_back(make_pair($1->getnameofsymbol(), -1));

		$$ = new symbol_info($1->getnameofsymbol(),"declaration_list");
	}
	| ID LTHIRD CONST_INT RTHIRD
	{
		outlog<<"At line no: "<<line_num<<" declaration_list : ID LTHIRD CONST_INT RTHIRD "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<"["<<$3->getnameofsymbol()<<"]"<<endl<<endl;

		decl_buffer.push_back(make_pair($1->getnameofsymbol(), stoi($3->getnameofsymbol())));

		$$ = new symbol_info($1->getnameofsymbol()+"["+$3->getnameofsymbol()+"]","declaration_list");
	}
	;

statements : statement
	{
		outlog<<"At line no: "<<line_num<<" statements : statement "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"statements");
		BlockNode* blk = new BlockNode();
		if ($1->get_ast_node()) blk->add_statement((StmtNode*)$1->get_ast_node());
		$$->set_ast_node(blk);
	}
	| statements statement
	{
		outlog<<"At line no: "<<line_num<<" statements : statements statement "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<"\n"<<$2->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol()+"\n"+$2->getnameofsymbol(),"statements");
		BlockNode* blk = (BlockNode*)$1->get_ast_node();
		if (!blk) blk = new BlockNode();
		if ($2->get_ast_node()) blk->add_statement((StmtNode*)$2->get_ast_node());
		$$->set_ast_node(blk);
	}
	;

statement : variable_decl
	{
		outlog<<"At line no: "<<line_num<<" statement : variable_decl "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"statement");
		$$->set_ast_node($1->get_ast_node());
	}
	| expression_statement
	{
		outlog<<"At line no: "<<line_num<<" statement : expression_statement "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"statement");
		$$->set_ast_node($1->get_ast_node());
	}
	| compound_statement
	{
		outlog<<"At line no: "<<line_num<<" statement : compound_statement "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"statement");
		$$->set_ast_node($1->get_ast_node());
	}
	| FOR LPAREN expression_statement expression_statement expression RPAREN statement
	{
		outlog<<"At line no: "<<line_num<<" statement : FOR LPAREN expression_statement expression_statement expression RPAREN statement "<<endl<<endl;
		outlog<<"for("+$3->getnameofsymbol()+$4->getnameofsymbol()+$5->getnameofsymbol()+")\n"+$7->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info("for("+$3->getnameofsymbol()+$4->getnameofsymbol()+$5->getnameofsymbol()+")\n"+$7->getnameofsymbol(),"statement");
		ExprNode* init = NULL;
		ExprNode* cond = NULL;
		ExprNode* upd = (ExprNode*)$5->get_ast_node();
		// expression_statement may wrap ExprStmtNode; try to get underlying expr
		if ($3->get_ast_node()) {
			// ExprStmtNode holds the expr; for ForNode we need ExprNode*
			// For simplicity pass the ExprStmt's expr if possible, else nullptr
			init = NULL; // for loop init from expr_stmt is handled as side-effect of ExprStmt
		}
		if ($4->get_ast_node()) {
			cond = NULL;
		}
		StmtNode* body = (StmtNode*)$7->get_ast_node();
		// Better approach: extract expr from ExprStmtNode if present
		// For now create ForNode with available pieces
		ForNode* fn = new ForNode(
			(ExprNode*)$3->get_ast_node(),  // may be ExprStmtNode cast - careful
			(ExprNode*)$4->get_ast_node(),
			upd,
			body
		);
		$$->set_ast_node(fn);
	}
	| IF LPAREN expression RPAREN statement %prec LOWER_THAN_ELSE
	{
		outlog<<"At line no: "<<line_num<<" statement : IF LPAREN expression RPAREN statement "<<endl<<endl;
		outlog<<"if("+$3->getnameofsymbol()+")\n"+$5->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info("if("+$3->getnameofsymbol()+")\n"+$5->getnameofsymbol(),"statement");
		ExprNode* cond = (ExprNode*)$3->get_ast_node();
		StmtNode* then_s = (StmtNode*)$5->get_ast_node();
		if (cond && then_s) {
			$$->set_ast_node(new IfNode(cond, then_s, nullptr));
		}
	}
	| IF LPAREN expression RPAREN statement ELSE statement
	{
		outlog<<"At line no: "<<line_num<<" statement : IF LPAREN expression RPAREN statement ELSE statement "<<endl<<endl;
		outlog<<"if("+$3->getnameofsymbol()+")\n"+$5->getnameofsymbol()+"\nelse\n"+$7->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info("if("+$3->getnameofsymbol()+")\n"+$5->getnameofsymbol()+"\nelse\n"+$7->getnameofsymbol(),"statement");
		ExprNode* cond = (ExprNode*)$3->get_ast_node();
		StmtNode* then_s = (StmtNode*)$5->get_ast_node();
		StmtNode* else_s = (StmtNode*)$7->get_ast_node();
		if (cond && then_s) {
			$$->set_ast_node(new IfNode(cond, then_s, else_s));
		}
	}
	| WHILE LPAREN expression RPAREN statement
	{
		outlog<<"At line no: "<<line_num<<" statement : WHILE LPAREN expression RPAREN statement "<<endl<<endl;
		outlog<<"while("+$3->getnameofsymbol()+")\n"+$5->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info("while("+$3->getnameofsymbol()+")\n"+$5->getnameofsymbol(),"statement");
		ExprNode* cond = (ExprNode*)$3->get_ast_node();
		StmtNode* body = (StmtNode*)$5->get_ast_node();
		if (cond && body) {
			$$->set_ast_node(new WhileNode(cond, body));
		}
	}
	| PRINTLN LPAREN ID RPAREN SEMICOLON
	{
		outlog<<"At line no: "<<line_num<<" statement : PRINTLN LPAREN ID RPAREN SEMICOLON "<<endl<<endl;
		outlog<<"printf("<<$3->getnameofsymbol()<<");"<<endl<<endl;

		symbol_info *found = symtab->lookup($3->getnameofsymbol());
		if (found == NULL)
			semantic_error("Undeclared variable " + $3->getnameofsymbol());

		$$ = new symbol_info("printf("+$3->getnameofsymbol()+");","statement");
		// treat as function call expression statement
		FuncCallNode* fc = new FuncCallNode("printf", "void");
		fc->add_argument(new VarNode($3->getnameofsymbol(), found ? found->gettypeofsymbol() : "int"));
		$$->set_ast_node(new ExprStmtNode(fc));
	}
	| RETURN expression SEMICOLON
	{
		outlog<<"At line no: "<<line_num<<" statement : RETURN expression SEMICOLON "<<endl<<endl;
		outlog<<"return "<<$2->getnameofsymbol()<<";"<<endl<<endl;

		$$ = new symbol_info("return "+$2->getnameofsymbol()+";","statement");
		ExprNode* e = (ExprNode*)$2->get_ast_node();
		$$->set_ast_node(new ReturnNode(e));
	}
	;

expression_statement : SEMICOLON
	{
		outlog<<"At line no: "<<line_num<<" expression_statement : SEMICOLON "<<endl<<endl;
		outlog<<";"<<endl<<endl;

		$$ = new symbol_info(";","expression_statement");
		$$->set_data_type("void");
		$$->set_ast_node(new ExprStmtNode(nullptr));
	}
	| expression SEMICOLON
	{
		outlog<<"At line no: "<<line_num<<" expression_statement : expression SEMICOLON "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<";"<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol()+";","expression_statement");
		$$->set_data_type($1->get_data_type());
		$$->set_ast_node(new ExprStmtNode((ExprNode*)$1->get_ast_node()));
	}
	;

variable : ID
	{
		outlog<<"At line no: "<<line_num<<" variable : ID "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"variable");
		symbol_info *found = symtab->lookup($1->getnameofsymbol());
		string dtype = "int";
		if (found == NULL)
		{
			semantic_error("Undeclared variable " + $1->getnameofsymbol());
			$$->set_data_type("undeclared");
			dtype = "undeclared";
		}
		else
		{
			$$->set_data_type(found->gettypeofsymbol());
			dtype = found->gettypeofsymbol();
			if (found->is_array())
				$$->set_is_array(true);
			if (found->is_function())
				$$->set_is_function(true);
		}
		$$->set_ast_node(new VarNode($1->getnameofsymbol(), dtype, nullptr));
	}
	| ID LTHIRD expression RTHIRD
	{
		outlog<<"At line no: "<<line_num<<" variable : ID LTHIRD expression RTHIRD "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<"["<<$3->getnameofsymbol()<<"]"<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol()+"["+$3->getnameofsymbol()+"]","variable");
		symbol_info *found = symtab->lookup($1->getnameofsymbol());
		string dtype = "int";
		if (found == NULL)
		{
			semantic_error("Undeclared variable " + $1->getnameofsymbol());
			$$->set_data_type("undeclared");
			dtype = "undeclared";
		}
		else
		{
			if (!found->is_array())
			{
				semantic_error("variable is not of array type : " + $1->getnameofsymbol());
			}
			if ($3->get_data_type() != "int")
			{
				semantic_error("array index is not of integer type : " + $1->getnameofsymbol());
			}
			$$->set_data_type(found->gettypeofsymbol());
			dtype = found->gettypeofsymbol();
			// indexed array element is NOT an array anymore
			$$->set_is_array(false);
		}
		$$->set_ast_node(new VarNode($1->getnameofsymbol(), dtype, (ExprNode*)$3->get_ast_node()));
	}
	;

expression : logic_expression
	{
		outlog<<"At line no: "<<line_num<<" expression : logic_expression "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"expression");
		$$->set_data_type($1->get_data_type());
		$$->set_is_array($1->is_array());
		$$->set_ast_node($1->get_ast_node()); // pass through AST
	}
	| variable ASSIGNOP logic_expression
	{
		outlog<<"At line no: "<<line_num<<" expression : variable ASSIGNOP logic_expression "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<"="<<$3->getnameofsymbol()<<endl<<endl;

		// type checks
		if ($1->is_array() && $1->getnameofsymbol().find('[') == string::npos)
		{
			semantic_error("variable is of array type : " + $1->getnameofsymbol());
		}
		// float assigned to int
		if ($1->get_data_type() == "int" && $3->get_data_type() == "float")
		{
			// warning style - still count as per assignment
			// semantic_error("Warning: possible conversion from float to int");
		}
		// void function result assigned
		if ($3->get_data_type() == "void")
		{
			semantic_error("Void function used in expression");
		}

		$$ = new symbol_info($1->getnameofsymbol()+"="+$3->getnameofsymbol(),"expression");
		$$->set_data_type($1->get_data_type());
		// Lab 4: Create AssignNode
		VarNode* vn = (VarNode*)$1->get_ast_node();
		ExprNode* en = (ExprNode*)$3->get_ast_node();
		if (vn && en) {
			AssignNode* assignNode = new AssignNode(vn, en, $1->get_data_type());
			$$->set_ast_node(assignNode);
		}
	}
	;

logic_expression : rel_expression
	{
		outlog<<"At line no: "<<line_num<<" logic_expression : rel_expression "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"logic_expression");
		$$->set_data_type($1->get_data_type());
		$$->set_is_array($1->is_array());
		$$->set_ast_node($1->get_ast_node());
	}
	| rel_expression LOGICOP rel_expression
	{
		outlog<<"At line no: "<<line_num<<" logic_expression : rel_expression LOGICOP rel_expression "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<$2->getnameofsymbol()<<$3->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol()+$2->getnameofsymbol()+$3->getnameofsymbol(),"logic_expression");
		$$->set_data_type("int"); // LOGICOP result is int
		ExprNode* l = (ExprNode*)$1->get_ast_node();
		ExprNode* r = (ExprNode*)$3->get_ast_node();
		if (l && r) {
			$$->set_ast_node(new BinaryOpNode($2->getnameofsymbol(), l, r, "int"));
		}
	}
	;

rel_expression : simple_expression
	{
		outlog<<"At line no: "<<line_num<<" rel_expression : simple_expression "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"rel_expression");
		$$->set_data_type($1->get_data_type());
		$$->set_is_array($1->is_array());
		$$->set_ast_node($1->get_ast_node());
	}
	| simple_expression RELOP simple_expression
	{
		outlog<<"At line no: "<<line_num<<" rel_expression : simple_expression RELOP simple_expression "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<$2->getnameofsymbol()<<$3->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol()+$2->getnameofsymbol()+$3->getnameofsymbol(),"rel_expression");
		$$->set_data_type("int"); // RELOP result is int
		ExprNode* l = (ExprNode*)$1->get_ast_node();
		ExprNode* r = (ExprNode*)$3->get_ast_node();
		if (l && r) $$->set_ast_node(new BinaryOpNode($2->getnameofsymbol(), l, r, "int"));
	}
	;

simple_expression : term
	{
		outlog<<"At line no: "<<line_num<<" simple_expression : term "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"simple_expression");
		$$->set_data_type($1->get_data_type());
		$$->set_is_array($1->is_array());
		$$->set_ast_node($1->get_ast_node());
	}
	| simple_expression ADDOP term
	{
		outlog<<"At line no: "<<line_num<<" simple_expression : simple_expression ADDOP term "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<$2->getnameofsymbol()<<$3->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol()+$2->getnameofsymbol()+$3->getnameofsymbol(),"simple_expression");
		$$->set_data_type(result_type($1->get_data_type(), $3->get_data_type()));
		ExprNode* l = (ExprNode*)$1->get_ast_node();
		ExprNode* r = (ExprNode*)$3->get_ast_node();
		if (l && r) $$->set_ast_node(new BinaryOpNode($2->getnameofsymbol(), l, r, $$->get_data_type()));
	}
	;

term : unary_expression
	{
		outlog<<"At line no: "<<line_num<<" term : unary_expression "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"term");
		$$->set_data_type($1->get_data_type());
		$$->set_is_array($1->is_array());
		$$->set_ast_node($1->get_ast_node());
	}
	| term MULOP unary_expression
	{
		outlog<<"At line no: "<<line_num<<" term : term MULOP unary_expression "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<$2->getnameofsymbol()<<$3->getnameofsymbol()<<endl<<endl;

		string op = $2->getnameofsymbol();
		if (op == "%")
		{
			if ($1->get_data_type() != "int" || $3->get_data_type() != "int")
			{
				semantic_error("Non-integer operand on modulus operator");
			}
		}
		if ((op == "/" || op == "%") && ($3->getnameofsymbol() == "0" || $3->getnameofsymbol() == "0.0"))
		{
			semantic_error("Division by Zero");
		}

		$$ = new symbol_info($1->getnameofsymbol()+$2->getnameofsymbol()+$3->getnameofsymbol(),"term");
		if (op == "%")
			$$->set_data_type("int");
		else
			$$->set_data_type(result_type($1->get_data_type(), $3->get_data_type()));
		ExprNode* l = (ExprNode*)$1->get_ast_node();
		ExprNode* r = (ExprNode*)$3->get_ast_node();
		if (l && r) $$->set_ast_node(new BinaryOpNode(op, l, r, $$->get_data_type()));
	}
	;

unary_expression : ADDOP unary_expression
	{
		outlog<<"At line no: "<<line_num<<" unary_expression : ADDOP unary_expression "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<$2->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol()+$2->getnameofsymbol(),"unary_expression");
		$$->set_data_type($2->get_data_type());
		ExprNode* e = (ExprNode*)$2->get_ast_node();
		if (e) $$->set_ast_node(new UnaryOpNode($1->getnameofsymbol(), e, $2->get_data_type()));
	}
	| NOT unary_expression
	{
		outlog<<"At line no: "<<line_num<<" unary_expression : NOT unary_expression "<<endl<<endl;
		outlog<<"!"<<$2->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info("!"+$2->getnameofsymbol(),"unary_expression");
		$$->set_data_type("int");
		ExprNode* e = (ExprNode*)$2->get_ast_node();
		if (e) $$->set_ast_node(new UnaryOpNode("!", e, "int"));
	}
	| factor_info
	{
		outlog<<"At line no: "<<line_num<<" unary_expression : factor_info "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"unary_expression");
		$$->set_data_type($1->get_data_type());
		$$->set_is_array($1->is_array());
		$$->set_ast_node($1->get_ast_node());
	}
	;

factor_info : factor
	{
		outlog<<"At line no: "<<line_num<<" factor_info : factor "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"factor_info");
		$$->set_data_type($1->get_data_type());
		$$->set_is_array($1->is_array());
		$$->set_ast_node($1->get_ast_node());
	}
	;

factor : variable
	{
		outlog<<"At line no: "<<line_num<<" factor : variable "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"factor");
		$$->set_data_type($1->get_data_type());
		$$->set_is_array($1->is_array());
		$$->set_ast_node($1->get_ast_node());
	}
	| ID LPAREN argument_list RPAREN
	{
		outlog<<"At line no: "<<line_num<<" factor : ID LPAREN argument_list RPAREN "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<"("<<$3->getnameofsymbol()<<")"<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol()+"("+$3->getnameofsymbol()+")","factor");

		symbol_info *found = symtab->lookup($1->getnameofsymbol());
		if (found == NULL)
		{
			semantic_error("Undeclared function: " + $1->getnameofsymbol());
			$$->set_data_type("undeclared");
		}
		else if (!found->is_function())
		{
			// function call with non-function
			semantic_error("Undeclared function: " + $1->getnameofsymbol());
			$$->set_data_type("error");
		}
		else
		{
			$$->set_data_type(found->gettypeofsymbol());
			vector<string> expected = found->get_param_types();
			vector<string> actual = $3->get_arg_types();

			if ((int)actual.size() != found->get_param_count())
			{
				semantic_error("Inconsistencies in number of arguments in function call: " + $1->getnameofsymbol());
			}
			else
			{
				for (size_t i = 0; i < actual.size(); i++)
				{
					// type mismatch (including array used as non-array arg)
					if (actual[i] == "array" || (actual[i] != expected[i] && actual[i] != "error" && actual[i] != "undeclared"))
					{
						// if actual is array type marker
						if (actual[i] == "array" || actual[i].find("array:") == 0)
						{
							// already reported "variable is of array type"
							semantic_error("argument " + to_string(i+1) + " type mismatch in function call: " + $1->getnameofsymbol());
						}
						else if (actual[i] != expected[i])
						{
							semantic_error("argument " + to_string(i+1) + " type mismatch in function call: " + $1->getnameofsymbol());
						}
					}
				}
			}
			// void function cannot be part of expression - checked by caller context if needed
			if (found->gettypeofsymbol() == "void")
			{
				// allowed as statement expression; if used further may be issue
			}
		}
		// Lab 4: build FuncCallNode
		string rtype = $$->get_data_type();
		FuncCallNode* fc = new FuncCallNode($1->getnameofsymbol(), rtype);
		// arguments AST stored on argument_list via a temporary vector of ExprNode*
		// We use get_ast_node of argument_list which we will set to ArgumentsNode
		ArgumentsNode* an = (ArgumentsNode*)$3->get_ast_node();
		if (an) {
			for (size_t i = 0; i < an->size(); i++) {
				fc->add_argument(an->get_argument(i));
			}
		}
		$$->set_ast_node(fc);
	}
	| LPAREN expression RPAREN
	{
		outlog<<"At line no: "<<line_num<<" factor : LPAREN expression RPAREN "<<endl<<endl;
		outlog<<"("<<$2->getnameofsymbol()<<")"<<endl<<endl;

		$$ = new symbol_info("("+$2->getnameofsymbol()+")","factor");
		$$->set_data_type($2->get_data_type());
		$$->set_ast_node($2->get_ast_node());
	}
	| CONST_INT
	{
		outlog<<"At line no: "<<line_num<<" factor : CONST_INT "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"factor");
		$$->set_data_type("int");
		$$->set_ast_node(new ConstNode($1->getnameofsymbol(), "int"));
	}
	| CONST_FLOAT
	{
		outlog<<"At line no: "<<line_num<<" factor : CONST_FLOAT "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"factor");
		$$->set_data_type("float");
		$$->set_ast_node(new ConstNode($1->getnameofsymbol(), "float"));
	}
	| variable INCOP
	{
		outlog<<"At line no: "<<line_num<<" factor : variable INCOP "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<"++"<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol()+"++","factor");
		$$->set_data_type($1->get_data_type());
		// treat as assignment a = a + 1 for code gen simplicity
		VarNode* vn = (VarNode*)$1->get_ast_node();
		if (vn) {
			ExprNode* one = new ConstNode("1", "int");
			ExprNode* add = new BinaryOpNode("+", new VarNode(vn->get_name(), vn->get_type()), one, vn->get_type());
			$$->set_ast_node(new AssignNode(vn, add, vn->get_type()));
		}
	}
	| variable DECOP
	{
		outlog<<"At line no: "<<line_num<<" factor : variable DECOP "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<"--"<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol()+"--","factor");
		$$->set_data_type($1->get_data_type());
		VarNode* vn = (VarNode*)$1->get_ast_node();
		if (vn) {
			ExprNode* one = new ConstNode("1", "int");
			ExprNode* sub = new BinaryOpNode("-", new VarNode(vn->get_name(), vn->get_type()), one, vn->get_type());
			$$->set_ast_node(new AssignNode(vn, sub, vn->get_type()));
		}
	}
	;

argument_list : arguments
	{
		outlog<<"At line no: "<<line_num<<" argument_list : arguments "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"argument_list");
		$$->set_arg_types($1->get_arg_types());
		$$->set_ast_node($1->get_ast_node());
	}
	|
	{
		outlog<<"At line no: "<<line_num<<" argument_list : "<<endl<<endl;
		outlog<<""<<endl<<endl;

		$$ = new symbol_info("","argument_list");
		$$->set_ast_node(new ArgumentsNode());
	}
	;

arguments : arguments COMMA logic_expression
	{
		outlog<<"At line no: "<<line_num<<" arguments : arguments COMMA logic_expression "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<","<<$3->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol()+","+$3->getnameofsymbol(),"arguments");
		vector<string> args = $1->get_arg_types();
		if ($3->is_array())
		{
			// extract name
			string n = $3->getnameofsymbol();
			size_t br = n.find('[');
			if (br != string::npos) n = n.substr(0, br);
			semantic_error("variable is of array type : " + n);
			args.push_back("array");
		}
		else
			args.push_back($3->get_data_type());
		$$->set_arg_types(args);
		ArgumentsNode* an = (ArgumentsNode*)$1->get_ast_node();
		if (!an) an = new ArgumentsNode();
		if ($3->get_ast_node()) an->add_argument((ExprNode*)$3->get_ast_node());
		$$->set_ast_node(an);
	}
	| logic_expression
	{
		outlog<<"At line no: "<<line_num<<" arguments : logic_expression "<<endl<<endl;
		outlog<<$1->getnameofsymbol()<<endl<<endl;

		$$ = new symbol_info($1->getnameofsymbol(),"arguments");
		vector<string> args;
		if ($1->is_array())
		{
			string n = $1->getnameofsymbol();
			size_t br = n.find('[');
			if (br != string::npos) n = n.substr(0, br);
			semantic_error("variable is of array type : " + n);
			args.push_back("array");
		}
		else
			args.push_back($1->get_data_type());
		$$->set_arg_types(args);
		ArgumentsNode* an = new ArgumentsNode();
		if ($1->get_ast_node()) an->add_argument((ExprNode*)$1->get_ast_node());
		$$->set_ast_node(an);
	}
	;

%%
void yyerror(const char *s)
{
    outlog << "Error at line " << line_num
           << ": " << s << endl;
}

int main(int c, char *v[])
{
	if(c != 2) 
	{
		cout<<"Usage: "<<v[0]<<" <input_file>"<<endl;
		return 0;
	}
	yyin = fopen(v[1], "r");
	outlog.open("22299222_log.txt", ios::trunc);
	outerr.open("22299222_error.txt", ios::trunc);
	outcode.open("code.txt", ios::trunc);
	
	if(yyin == NULL)
	{
		cout<<"Couldn't open file"<<endl;
		return 0;
	}

	symtab = new symbol_table(10);
	ast_root = NULL;

	yyparse();
	
	outlog<<"Total lines: "<<line_num<<endl<<endl;

	outlog<<"Symbol Table"<<endl<<endl;
	symtab->print_all_scopes(outlog);

	outlog<<"Total errors: "<<error_count<<endl;
	outerr<<"Total errors: "<<error_count<<endl;

	// Generate three-address code from AST
	if (ast_root != NULL) {
		outlog << endl << "===== AST Code Generation =====" << endl << endl;
		ThreeAddrCodeGenerator codegen(ast_root, outcode);
		codegen.generate();
		outlog << "Three-address code written to code.txt" << endl;
	} else {
		outcode << "; No AST root available for code generation" << endl;
		outlog << "Warning: No AST root, empty code.txt generated" << endl;
	}

	// don't exit_scope on global - just delete
	delete symtab;
	if (ast_root) delete ast_root;
	
	outlog.close();
	outerr.close();
	outcode.close();
	
	fclose(yyin);
	
	return 0;
}
