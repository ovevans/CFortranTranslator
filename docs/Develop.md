# Debug
## Visual Studio debug configurations
1. The **Debug** mode accept command line arguments `argv[]` which is set to default values in VS project configurations
	when running **Debug** mode, program automaticly loads codes from file [/demos/1.txt](/demos/1.txt)
	
2. The **Develop** mode invoke the function `void debug()` which is defined in [/src/develop.cpp](/src/develop.cpp)
3. The **Release** is same as the **Debug** mode except for default values which is not set

# Parsing
Currently, CFortranTranslator use [/src/grammar/simple_lexer.cpp](/src/grammar/simple_lexer.cpp) as tokenizer, [/src/grammar/for90.y](/src/grammar/for90.y) as parser

## Tokenizer(by flex)
`#define USE_LEX` to enable tokenizer generated by flex from [/src/grammar/for90.l](/src/grammar/for90.l)

## Tokenizer(by simple\_lexer)
`#undef USE_LEX` to enable [simple\_lexer](/src/grammar/simple_lexer.cpp)

simple\_lexer is a more flexible tokenizer in order to handle some features of fortran

e.g. Fortran's continuation can exist between a token
```
        inte
     *ger :: a(10)
```

## Parser
The parser is generated by bison from [/src/grammar/for90.y](/src/grammar/for90.y)
The parser calls `int yylex(void)` to get one token from tokenizer at a time
`int yylex(void)` is defined to `pure_yylex` when using flex, and `simple_yylex` when using simple\_lexer

### Macros
In [/src/parser/parser.h](/src/parser/parser.h), several helper macros are defined to help managing nodes. These macros are defined to different value according to different memory management strategies. There behaviour is controlled by defining `USE_TRIVIAL`/`USE_POINTER` or none of them.

1. `YY2ARG` get a `ParseNode &` from bison's arguments `$n`
    `$n` can be `ParseNode` or `ParseNode *`
2. `RETURN_NT` generates a bison's result `$$`(namely `ParseNode *`) from  `ParseNode`, `RETURN_NT` does opposite work of `YY2ARG`
    `$$` can be `ParseNode` or `ParseNode *`
3. `CLEAN_RIGHT`/`CLEAN_DELETE`/`CLEAN_REUSE` clear all bison's arguments
	- `CLEAN_RIGHT`: a general rule which is deprecated and replaced by the following two cases
	- `CLEAN_DELETE`: tokens can't be reused in generated NT, usually are NTs
	- `CLEAN_REUSE`: tokens can be reused in generated NT, usually are Ts. 
		`CLEAN_REUSE` may be or may not be reused in differenct situations:
		1. `USE_TRIVIAL`: Reuse
		2. `USE_POINTER`: Reuse
		3. else: Copy
	- e.g.
		```
		case_stmt_elem : YY_CASE '(' dimen_slice ')' at_least_one_end_line suite
		```
		`CLEAN_DELETE` includes `YY_CASE`, `'('`, `')'`, `at_least_one_end_line`
		`CLEAN_REUSE` includes `dimen_slice`, `suite`
	
## Extend grammar
This translator supports a subset of Fortran90's grammar.
Grammar can be extended by adding new rules into [/src/grammar/for90.y](/src/grammar/for90.y)
1. Declare new token by `%token` in [/src/grammar/for90.y](/src/grammar/for90.y)
2. Add pattern of this token in [/src/grammar/for90.l](/src/grammar/for90.l)
3. Add rules related to the token in [/src/grammar/for90.y](/src/grammar/for90.y)
4. Update bytecodes and grammar tokens in [/src/parser/Intent.h](/src/parser/Intent.h)
5. Register keyword in [/src/parser/tokenizer.cpp](/src/parser/tokenizer.cpp)(if this token is keyword)
6. If this keyword are made up of more than **one** words, reduction conflicts may be caused between the whole keyword and its prefix, so this keyword must be handled specially by:
    - if this keyword is made up of non-word symbols without spaces between them. e.g. `(/` is made up of `(` and `/`. 
        Just add the whole word as a rule to for90.l
    - if rule's keyword is made up words seperated by spaces, like `else if`
        add a new item into `forward1` in [/src/parser/tokenizer.cpp](/src/parser/tokenizer.cpp)
        the first part `else` don't need to be registered as a keyword
7. Update translation rules in [/src/target/gen_config.h](/src/target/gen_config.h.h)

## Add new implemetation of Fortran's intrinsic function
This for90std library implements a subset of Fortran90's intrinsic functions.
1. Implement this function and included it in [for90std/for90std.h](/for90std/for90std.h)
	- if a parameter is **optional** in fortran, wrap it with `foroptional`, and log all parameters of this function in [/gen_config.cpp](/gen_config.cpp)
    - if the parameter is the **only** optional parameter, can omit `foroptional` wrapper
2. Update `funcname_map` in [/src/target/gen_config.cpp](/src/target/gen_config.cpp) if necessary


# Grammar rules explanation
In this section, serveral specific generating rules are discussed
## argtable, dimen_slice, pure_paramtable
`argtable`, `dimen_slice`, `pure_paramtable` are a list of different items seprated by `,`
### Constitution
- `argtable` is a list of `exp`(ref `is_exp()`)
- `dimen_slice` is a list of `slice`(`NT_SLICE`) or `exp`
- `pure_paramtable` is a list of `keyvalue`(`NT_KEYVALUE`/`NT_VARIABLE_ENTITY`) or `slice` or `exp`
    `pure_paramtable` will be re-generated in `regen_function_array` in [/src/target/gen_callable.cpp](/src/target/gen_callable.cpp)
- `paramtable` is `argtable` or `dimen_slice` or `pure_paramtable`
#### Promotion
- `argtable` + `slice` = `dimen_slice`, all elements in `argtable` will be promote to `slice`(with one child)
- `argtable` + `keyvalue` = `pure_paramtable`, all elements in `argtable` will be promote to `keyvalue`
- `dimen_slice` + `keyvalue` or `pure_paramtable` + `slice` is illegal
	
### type_spec, type_name, type_selector

>	(3) The suffix "- spec" is used consistently for specifiers, such as keyword actual arguments and
>		input / output statement specifiers.It also is used for type declaration attribute specifications(for
>			example, "array - spec" in R512), and in a few other cases.

>	(4) When reference is made to a type parameter, including the surrounding parentheses, the term
>		"selector" is used.See, for example, "length - selector"(R507) and "kind - selector"(R505).

You can use `REAL(x)` to get the float copy of x, however, you can also use `REAL(kind = 8)` to specify a floating number which is same to `long double` rather than `double`, so it may cause conflict. 
To specify, `type_name` is like `INTEGER` and a `type_spec` is like `INTEGER(kind = 4)`, `type_nospec` can be head of `callable`, `type_spec` is not.

### array builder
`NT_FUCNTIONARRAY` and `NT_HIDDENDO` will **NOT** be promote to `NT_EXPRESSION`

### stmt, suite
- `stmt` is statement end with ';' or '\n'
- `suite` is a set of `stmt`

## A partial table of rules

|rules|left side|right side|
|:-:|:-:|:-:|
| fortran_program | root | wrappers |
| wrappers |  | wrapper + |
| wrapper | / | function_decl / program |
| function_decl | NT_FUNCTIONDECLARE |  |
| var_def | NT_VARIABLEDEFINE/NT_DECLAREDVARIABLE |   |
| keyvalue | NT_VARIABLE_ENTITY(namely NT_KEYVALUE) | variable, NT_EXPRESSION / NT_VARIABLEINITIALDUMMY |
| | NT_VARIABLE_ENTITY | variable, exp |
| suite | NT_SUITE | stmt |
| stmt |  | exp / var_def / compound_stmt / output_stmt / input_stmt / dummy_stmt / let_stmt / jump_stmt / interface_decl |
| | NT_ARRAYBUILDER_LIST | (NT_HIDDENDO / NT_FUNCTIONARRAY / exp)  |
| type_spec |  | type_name / (type_name, type_selector) |

# Target code generating
## Lazy generating
### regen/gen/reused function
When using lazy gen strategy, the node of non-terminal on the left side can change nodes of non-terminals on the right side. which means the AST is not immutable.

1. `regen_` function 
	`regen_` functions are declared in [/src/target/codegen.h](/src/target/codegen.h)
	
	A `regen_` function will change its input `ParseNode &`
	
2. `gen_` function 
	`gen_` functions are declared in [/src/target/codegen.h](/src/target/codegen.h)
	
	A `gen_` function will not change its input `const ParseNode &`.  The `gen_` function uses it input to generate and return a new `ParseNode`. The function may copy part of it's input as its child nodes.
	
3. `gen_xxx_reused` function
	`gen_xxx_reused` function has a form like `gen_xxx_reused`, are declared in [/src/target/codegen.h](/src/target/codegen.h)
	
	Different from `gen_` function, a `gen_reused` function has input `ParseNode &`. Instead of copy some of its input like `gen_` functions do, a `gen_reused` reuse some its input, by adding pointers to them  directly.
	
	See parser:macros for more

## Order of generating
### Upper level Nodes of AST(above stmt level)
Due to fortran's feature of implicit declaration, code above `stmt` level, including `function_decl`, `program` can only be re-generated with correct type after the whole AST is built, by following steps:
1. `gen_fortran_program` handles `program`, `function_decl`
2. `regen_suite` handles `suite` rule
3. `regen_common` generates `common` statement code

### Variables and functions
The implicit declaration feature should also be considered when generating variables and functions, see variable definition/generate functions.

## Name mapping
Many type names and function names are mapped in order to avoid possible conflicts, the mapping is defined by `pre_map` and `funcname_map` in [/src/target/gen_config.h](/src/target/gen_config.h)

`pre_map` and `funcname_map` have different usages:
1. Mappings defined in `pre_map` are checked when doing tokenizing in [/src/grammar/for90.l](/src/grammar/for90.l). In this stage, keywords and operators are replaced

2. Mappings defined in `funcname_map` are checked when calling `regen_function_array` in [/src/target/gen_callable.cpp](/src/target/gen_callable.cpp). In this stage, only intrinsic functions' names are replaced to avoid possible confliction with other functions.

## Variable definition
### 3-fold strategy
Currently, variable is generated lazily, so the whole process happens after the AST is built.
1. Step 1:
    1. Case 1: when encountering a `UnknownVariant` during parsing (`regen_exp`, after the AST is built):
        
        ** Variables are registered to symbol table mostly in the condition**
        All variables, **once** reached by the parser will be registered to symbol table, by calling `check_implicit_variable`.  
		
		`check_implicit_variable` checks whether this variable has been registered to `gen_context().variables` by the otehr cases already. If this variable hasn't been registed, `check_implicit_variable` will register it to `gen_context().variables` by:
		1. Add `VariableInfo` node 
		2. `.type` is deduced by its name in function `gen_implicit_type`
		3. Set `.implicit_defined` = `true`, if an explicit declaration of this variable is found later, `.implicit_defined` will be set back to `false` automatically.
		4. `.vardef` is pointer(`!= nullptr`) to a `ParseNode` node. 
		5. Set `commonblock_name` = `""`, `commonblock_index` = `0`, if this variable is found belong to a common block, this two fields will be set.

    2. Case 2: when encounter `NT_COMMONBLOCK`(in `regen_stmt`, after the AST is built):

        **This is an explicit definition**

        Call `regen_common` to register `VariableInfo` into `gen_context().variables`, mark `commonblock_name` and `commonblock_index`
    3. Case  3: when encounter `NT_VARIABLEDEFINESET` and `NT_VARIABLEDEFINE`(in `regen_stmt`, after the AST is built):

        **This is an explicit definition**

        These two nodes are generated into `NT_VARIABLEDEFINESET` and `NT_VARIABLEDEFINE`, in [/src/grammar/for90.y](/src/grammar/for90.y).
        Register(add a new `VariableInfo` only when the variable is never used, or **modify** the exsiting `VariableInfo`, for the most cases) corresponding `VariableInfo` to symbol table.
	
	Step 1 works simultanously with `regen_` functions below suite level. After Step 1, all variables, whether explicit or implicit, are registered. However there is an exception that all implicit variables (e.g. `A`) used to initialize an variable (e.g. `B`) will not be registed until `regen_vardef` is called to `B`, in Step 2
	
	```
	integer A = B + 1 ! B is not registered
	```
2. Step 2:

    This procedure is defined in the function `regen_all_variables`, which includes a `while`-loop in which `regen_vardef` is called to every variable. This `while`-loop can't be replaced by an 1-pass `for`-loop, because `regen_vardef` may introduce new variables, according to Step 1. After the `while`-loop, all `VariableInfo` of this suite are generated(and their `.generate` field will all set to `true`).

3. Step 3:

    This procedure is defined in the function `regen_all_variables_decl_str`, according to function's 2-phase generating strategy. `regen_all_variables_decl_str` is called in `regen_function_2`, it will generate code for variables generated in Step 2. The generated codes depends on  whether this variable is common block.

### Common block

Common block is in global name space(finfo = `get_function("", "")`, vinfo = `get_commonblock(commonblock_name)->variables[commonblock_index]` = `get_variable("", "BLOCK_" + commonblock_name, local_varname)`)

### Interface
1. All items in interface are firstly variables, so it will be
    1. registered by `add_variable` under `finfo->local_name`
    2. its `local_name` will be exactly the item's name

2. All items in interface can also considered to be function(with no function body), so it will be
    1. registered by `add_function` under `get_context().current_module`
    2. its `local_name` will be `finfo->local_name + "@" + the item's name`

## Generate functions
Functions in fortran are strongly connected:
1. Functions shares common blocks, common blocks have relationship with body of function it belongs to.
	so variable decl part of a function must generated after all information of common block is gathered, which requires more than 1-pass scan of all functions.
	
2. Call function with keyword arguments needs the body of callee function parsed

### 2-fold strategy

# ParseNode(AST)
All parse tree nodes are defined in [/src/Intent.h](/src/Intent.h) with an `NT_` prefix
### struct ParseNode
1. fs:
	* fs.CurrentTerm.what: immediate-generated code, generated from child's `fs.CurrentTerm.what`, or from other infomations
	* fs.CurrentTerm.token: refer [/src/Intent.h](/src/Intent.h)
2. child
3. attr:
	attrs including
	* FunctionAttr
	* VariableDescAttr
4. father: pointer to parent node

## Nodes

Child ParseNode may also be referred when generating upper level ParseNode, so do not change child index of:

1. `NT_VARIABLE_ENTITY`: referred in `function_decl`
2. `NT_FUNCTIONDECLARE`: can represent interface, referred in `paramtable` and `function_decl`

# Symbols
All variables(including `commom` block) and functions is now logged in [/src/Variable.h](/src/Variable.h) and [/src/Function.h](/src/Function.h) by
`VariableInfo` and `FunctionInfo`

## VariableDesc
| Item | Rule |
|:-:|:-:|
| kind | typecast_spec |
| len | typecast_spec |
| dimension | variable_desc_elem |
| intent | variable_desc_elem |
| optional | variable_desc_elem |
| parameter | variable_desc_elem |

## Attributes
`->` means a `ParseNode` has this `ParseAttr`

| ParseAttr | Usage |
|:-:|:-:|
| `VariableDescAttr` | NT_DECLAREDVARIABLE or NT_VARIABLEDEFINE or NT_VARIABLEINTIAL nodes of NT_VARIABLEDEFINE.NT_PARAMTABLE_PURE |
| `FunctionAttr` | NT_FUNCTIONDECLARE |
| `VarialbeAttr` | NT_FUNCTIONDECLARE |

