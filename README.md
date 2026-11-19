# mini-c-compiler-flex-bison

A compiler front-end for a C subset, built with **Flex** and **Bison** in C++. It tokenizes the source, parses it, performs semantic checks with a scoped symbol table, builds an **Abstract Syntax Tree (AST)**, and generates **Three-Address Code (TAC)**.

Developed for **CSE420 (Compiler Design) – Lab 4**, BRAC University.

## Features

- **Lexical analysis** (`22299222.l`): keywords, identifiers, int/float constants, operators, punctuation, line tracking
- **Parsing** (`22299222.y`): functions, parameters, declarations (including arrays), expressions, `if`/`else`, `while`, `for`, `return`, function calls
- **Semantic analysis**
  - Multiple declarations of variables, parameters, or functions
  - Undeclared variables and functions
  - `void` variable declarations and `void` functions used in expressions
  - Array misuse (indexing a non-array, using an array without an index, non-integer index)
  - Modulus with non-integer operands, division by zero
  - Function call argument count and type mismatches
  - Int/float type promotion in arithmetic
- **Symbol table** (`symbol_table.h`, `scope_table.h`, `symbol_info.h`): nested scope tables with unique IDs and a hash-based lookup
- **AST** (`ast.h`): node classes for expressions, statements, declarations, functions and the program
- **Three-address code generation** (`three_addr_code.h`): temporaries, labels, `goto`/conditional jumps, `param`/`call`, and `func begin`/`func end` markers

## Project Structure

```
.
├── 22299222.l          # Flex lexer
├── 22299222.y          # Bison grammar, semantic actions, main()
├── ast.h               # AST node classes + code generation methods
├── three_addr_code.h   # TAC generator driver
├── symbol_info.h       # Symbol entry (name, type, array/function info)
├── scope_table.h       # Single scope (hash table)
├── symbol_table.h      # Scope stack management
├── input.c             # Sample input program
└── script.sh           # Build-and-run script
```

## Requirements

- `bison`
- `flex`
- `g++`

On Debian/Ubuntu:

```bash
sudo apt install bison flex g++
```

## Build and Run

```bash
chmod +x script.sh
./script.sh
```

This runs Bison, then Flex, compiles both with `g++`, links `a.out`, and runs it on `input.c`.

To run on your own file:

```bash
./a.out your_program.c
```

## Output Files

| File | Contents |
|------|----------|
| `22299222_log.txt` | Grammar rules reduced, symbol table / scope dumps |
| `22299222_error.txt` | Semantic errors with line numbers |
| `code.txt` | Generated three-address code |

## Example

Input (`input.c`):

```c
int func(int a, float b) {
    return a+b;
}

void main () {
    int a, b, c, i;
    int e, f[10], g[11];
    a = 1;
    b = 2;
    c = func(a, b);

    float d;
}
```

The generated `code.txt` contains TAC along these lines:

```
// Function: int func(int a, float b)
func begin func
t0 = a + b
return t0
func end func
```

Control flow is lowered to labels and jumps:

```
L0:
if t1 goto L1
goto L2
L1:
...
goto L0
L2:
```

## Pipeline

```
source.c → Lexer (Flex) → Parser (Bison) → Semantic checks + Symbol table → AST → Three-Address Code
```

## Author

**Sakib Amir** – CSE, BRAC University

## License

Released for educational purposes. Add a license of your choice (e.g. MIT) before reuse.
